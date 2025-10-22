const express = require('express');
const router = express.Router();
const db = require('../db');
const { requireAuth, requireRole } = require('../middleware/auth');

// ✅ Toți utilizatorii autentificați pot CITI; scrierea rămâne restricționată
router.use(requireAuth);

// ✅ Dacă e operator_admin, impunem operator_id-ul lui pe toate operațiile
router.use((req, _res, next) => {
  if (req.user?.role === 'operator_admin') {
    const opId = String(req.user.operator_id || '');
    // Forțăm operator_id în query (listări/filtrări)
    if (req.query && typeof req.query === 'object') {
      req.query.operator_id = opId;
    }
    // Forțăm operator_id în body (create/update)
    if (req.body && typeof req.body === 'object') {
      req.body.operator_id = Number(opId);
    }
  }
  next();
});


/* ================================================================
   GET /api/vehicles/:tripId/available
   Vehicule disponibile pentru o cursă (care aparțin aceluiași operator)
   ================================================================ */
router.get('/:tripId/available', async (req, res) => {
  const { tripId } = req.params;

  try {
    // operatorul cursei
    const { rows: op } = await db.query(
      `SELECT rs.operator_id
         FROM trips t
         JOIN route_schedules rs ON rs.id = t.route_schedule_id
        WHERE t.id = ?`,
      [tripId]
    );
    if (!op.length) {
      return res.status(404).json({ error: 'Cursa nu există.' });
    }
    const operatorId = op[0].operator_id;

    // vehiculele eligibile ale operatorului care NU sunt deja asociate cursei
    const { rows } = await db.query(
      `SELECT v.*
         FROM vehicles v
        WHERE v.operator_id = ?
          AND v.id NOT IN (
            SELECT vehicle_id FROM trip_vehicles WHERE trip_id = ?
          )
        ORDER BY v.name`,
      [operatorId, tripId]
    );

    res.json(rows);
  } catch (err) {
    console.error('Eroare la /api/vehicles/:tripId/available →', err);
    res.status(500).json({ error: 'Eroare internă la verificarea vehiculelor disponibile' });
  }
});


/* ================================================================
   GET /api/vehicles
   Listare vehicule cu filtre opționale ?operator_id= & ?type=
   ================================================================ */
router.get('/', async (req, res) => {
  try {
    const { operator_id, type } = req.query || {};
    const where = [];
    const params = [];

    if (operator_id) {
      where.push('operator_id = ?');
      params.push(Number(operator_id));
    }
    if (type) {
      where.push('type = ?');
      params.push(type);
    }

 const sql = `
   SELECT v.*, o.name AS operator_name
     FROM vehicles v
     LEFT JOIN operators o ON o.id = v.operator_id
   ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
   ORDER BY v.name
 `;
 const { rows } = await db.query(sql, params);
 res.json(rows);
  } catch (err) {
    console.error('Eroare la GET /api/vehicles:', err);
    res.status(500).json({ error: 'Eroare la fetch vehicles' });
  }
});


/* ================================================================
   GET /api/vehicles/:id/seats
   Returnează layoutul de locuri pentru un vehicul
   ================================================================ */
router.get('/:id/seats', async (req, res) => {
  const { id } = req.params;
  try {
    const { rows } = await db.query(
      `SELECT * FROM seats WHERE vehicle_id = ? ORDER BY row, seat_col, id`,
      [id]
    );
    res.json(rows);
  } catch (err) {
    console.error('Eroare la GET /api/vehicles/:id/seats →', err);
    res.status(500).json({ error: 'Eroare internă' });
  }
});




/* ================================================================
   GET /api/vehicles/:id
   Detalii vehicul după ID
   ================================================================ */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await db.query('SELECT * FROM vehicles WHERE id = ? LIMIT 1', [id]);
    if (!rows || rows.length === 0) return res.status(404).json({ error: 'Vehicul inexistent' });
    res.json(rows[0]);
  } catch (err) {
    console.error('Eroare la GET /api/vehicles/:id:', err);
    res.status(500).json({ error: 'Eroare la citirea vehiculului' });
  }
});




/* ================================================================
   PUT /api/vehicles/:id/seats/bulk
   Bulk upsert pentru locuri. Acceptă array de obiecte:
   [{id?, row, seat_col, label, seat_type, seat_number, pair_id, is_available}]
   Dacă elementul are {_delete:true} și id, atunci se șterge.
   ================================================================ */
router.put('/:id/seats/bulk', requireRole('admin','operator_admin'), async (req, res) => {
  const idRaw = req.params.id;
  const vehId = Number.parseInt(idRaw, 10);
  if (!Number.isFinite(vehId) || vehId <= 0) {
    // protecție: dacă frontend a trimis /vehicles/undefined/seats/bulk
    return res.status(400).json({
      error: 'ID vehicul invalid în URL.',
      detail: { id: idRaw }
    });
  }
  const incoming = Array.isArray(req.body) ? req.body : [];
  const conn = await db.getConnection();

  // Normalizare: FORȚĂM vehicle_id = vehId; permitem row = 0 (șofer/ghid)
  const norm = incoming.map(s => ({
    ...s,
    vehicle_id: vehId,
    row: s.row != null ? Number(s.row) : null,
    seat_col: s.seat_col != null ? Number(s.seat_col) : null,
    seat_number: s.seat_number != null ? Number(s.seat_number) : null,
    position: s.position != null ? Number(s.position) : null,
    is_available: s.is_available != null ? Number(s.is_available) : 1,
    label: s.label ?? null,
    seat_type: s.seat_type ?? 'normal',
    pair_id: s.pair_id != null ? Number(s.pair_id) : null,
  }));

  const toDelete = norm.filter(x => x._delete && x.id);
  const toUpdate = norm.filter(x => x.id && !x._delete);
  const toInsert = norm.filter(x => !x.id && !x._delete);

  try {
    await conn.beginTransaction();

    // 1) DELETE
    if (toDelete.length) {
      const ids = toDelete.map(x => x.id);
      await conn.query(
        `DELETE FROM seats WHERE vehicle_id = ? AND id IN (${ids.map(() => '?').join(',')})`,
        [vehId, ...ids]
      );
    }

    // 2) UPDATE (detectăm conflict pe (vehicle_id,row,seat_col))
    for (const s of toUpdate) {
      if (s.row == null || s.seat_col == null) {
        await conn.rollback();
        return res.status(400).json({ error: 'Row și seat_col sunt obligatorii la update.' });
      }

      const [conf] = await conn.query(
        `SELECT id FROM seats
         WHERE vehicle_id=? AND row=? AND seat_col=? AND id<>? LIMIT 1`,
        [vehId, s.row, s.seat_col, s.id]
      );
      if (conf.length) {
        await conn.rollback();
        return res.status(409).json({
          error: `Există deja un loc pe rând ${s.row}, coloană ${s.seat_col}.`,
        });
      }

      await conn.query(
        `UPDATE seats
           SET seat_number=?, position=?, row=?, seat_col=?, is_available=?, label=?, seat_type=?, pair_id=?
         WHERE id=? AND vehicle_id=?`,
        [
          s.seat_number, s.position, s.row, s.seat_col, s.is_available,
          s.label, s.seat_type, s.pair_id,
          s.id, vehId
        ]
      );
    }

    // 3) INSERT (UPSERT) – folosim vehId, nu ce vine în body
    for (const s of toInsert) {
      if (s.row == null || s.seat_col == null) {
        await conn.rollback();
        return res.status(400).json({ error: 'Row și seat_col sunt obligatorii la inserare.' });
      }

      await conn.query(
        `INSERT INTO seats
           (vehicle_id, seat_number, position, row, seat_col, is_available, label, seat_type, pair_id)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           seat_number=VALUES(seat_number),
           position=VALUES(position),
           is_available=VALUES(is_available),
           label=VALUES(label),
           seat_type=VALUES(seat_type),
           pair_id=VALUES(pair_id)`,
        [
          vehId,
          s.seat_number, s.position, s.row, s.seat_col, s.is_available,
          s.label, s.seat_type, s.pair_id
        ]
      );
    }

    await conn.commit();
    res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    console.error('Eroare la PUT /api/vehicles/:id/seats/bulk →', err);
    if (err?.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        error: 'Poziție deja ocupată (rând/coloană). Ajustează pozițiile și salvează din nou.',
        code: err.code, sqlMessage: err.sqlMessage
      });
    }
    if (err?.code === 'ER_TRUNCATED_WRONG_VALUE_FOR_FIELD') {
      return res.status(400).json({
        error: 'Valoare invalidă trimisă (verifică row/col/is_available).',
        code: err.code, sqlMessage: err.sqlMessage
      });
    }
    res.status(500).json({ error: 'Eroare la salvarea layoutului' });
  } finally {
    conn.release();
  }
});

;

/* ================================================================
   PATCH /api/vehicles/:id
   Actualizează detalii vehicul (nume, număr, tip, operator)
   ================================================================ */
router.patch('/:id', async (req, res) => {
  const { id } = req.params;
  const { name, seat_count, type, plate_number, operator_id } = req.body || {};
  try {
    await db.query(
      `UPDATE vehicles SET name=?, seat_count=?, type=?, plate_number=?, operator_id=? WHERE id=?`,
      [name, seat_count, type, plate_number, operator_id, id]
    );
    res.json({ ok: true });
  } catch (err) {
    console.error('Eroare la PATCH /api/vehicles/:id →', err);
    res.status(500).json({ error: 'Eroare la actualizarea vehiculului' });
  }
});


/* ================================================================
   POST /api/vehicles
   Creează un vehicul nou (nume, nr. înmatriculare, tip, operator)
   ================================================================ */
router.post('/', requireRole('admin','operator_admin'), async (req, res) => {
  try {
    const { name, plate_number, type, operator_id, seat_count } = req.body || {};
    if (!name || !type) {
      return res.status(400).json({ error: 'Lipsesc câmpuri obligatorii (name, type).' });
    }

    await db.query(
      `INSERT INTO vehicles (name, plate_number, type, operator_id, seat_count)
       VALUES (?, ?, ?, ?, ?)`,
      [name, plate_number || null, type, operator_id || null, seat_count || null]
    );
    // ia ID-ul garantat pe conexiune
    const { rows: idRow } = await db.query(`SELECT LAST_INSERT_ID() AS id`);
    const newId = idRow && idRow[0] ? idRow[0].id : null;
    res.status(201).json({ id: newId, ok: true });
  } catch (err) {
    console.error('Eroare la POST /api/vehicles →', err);
    res.status(500).json({ error: 'Eroare la crearea vehiculului' });
  }
});

/* ================================================================
   DELETE /api/vehicles/:id
   Șterge o mașină dacă nu e folosită pe curse (trips/trip_vehicles).
   Șterge layoutul (seats) aferent. Protejat în tranzacție.
   ================================================================ */
/* ================================================================
   DELETE /api/vehicles/:id
   ================================================================ */
router.delete('/:id', requireRole('admin','operator_admin'), async (req, res) => {
  const vehId = Number(req.params.id);
  if (!Number.isFinite(vehId) || vehId <= 0) {
    return res.status(400).json({ error: 'ID vehicul invalid.' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // 0) Existență (și blocăm rândul pe durata operației)
    const [[exists]] = await conn.query(
      `SELECT id FROM vehicles WHERE id = ? LIMIT 1 FOR UPDATE`,
      [vehId]
    );
    if (!exists) {
      await conn.rollback();
      return res.status(404).json({ error: 'Vehicul inexistent.' });
    }

    // 1) Blochează ștergerea dacă e folosit pe curse
    const [[t1]] = await conn.query(`SELECT COUNT(*) AS cnt FROM trips WHERE vehicle_id = ?`, [vehId]);
    const [[t2]] = await conn.query(`SELECT COUNT(*) AS cnt FROM trip_vehicles WHERE vehicle_id = ?`, [vehId]);
    if (Number(t1.cnt) > 0 || Number(t2.cnt) > 0) {
      await conn.rollback();
      return res.status(409).json({
        error: 'Mașina este asignată pe una sau mai multe curse. Eliberează mașina din curse înainte de ștergere.',
        trips_primary: Number(t1.cnt),
        trips_duplicate: Number(t2.cnt),
      });
    }

    // 2) Șterge layoutul de locuri
    await conn.query(`DELETE FROM seats WHERE vehicle_id = ?`, [vehId]);

    // 3) Șterge vehiculul
    await conn.query(`DELETE FROM vehicles WHERE id = ?`, [vehId]);

    await conn.commit();
    return res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    console.error('Eroare la DELETE /api/vehicles/:id →', err);
    return res.status(500).json({ error: 'Eroare la ștergerea vehiculului.' });
  } finally {
    conn.release();
  }
});



module.exports = router;
