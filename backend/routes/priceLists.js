const express = require('express');
const router = express.Router();
const db = require('../db');
const { requireAuth, requireRole } = require('../middleware/auth');

// --- PUBLIC INTERN (doar autentificat): pricing categories pentru calcule
//     (agent are nevoie să poată citi)
router.get('/pricing-categories', requireAuth, async (_req, res) => {
  try {
    const sql = `
      SELECT id, name
        FROM pricing_categories
       WHERE active = 1
       ORDER BY id
    `;
    const result = await db.query(sql);
    res.json(result.rows);
  } catch (err) {
    console.error('[GET /api/pricing-categories]', err);
    res.status(500).json({ error: 'Eroare server' });
  }
});


// 🔓 Citire: agent & driver (și evident admin / operator_admin)
// ✍️ Scriere: doar admin & operator_admin




// ✅ Dacă e operator_admin, impunem operator_id-ul lui pe toate operațiile
router.use((req, _res, next) => {
  if (req.user?.role === 'operator_admin') {
    const opId = String(req.user.operator_id || '');
    // Forțăm operator_id în query
    if (req.query && typeof req.query === 'object') {
      req.query.operator_id = opId;
    }
    // Forțăm operator_id și în body (create/update)
    if (req.body && typeof req.body === 'object') {
      req.body.operator_id = Number(opId);
    }
  }
  next();
});



// ✅ GET /api/price-lists
// ✅ GET /api/price-lists — CITIRE pentru admin/op_admin/agent/driver
router.get('/price-lists', requireAuth, requireRole('admin','operator_admin','agent','driver'), async (req, res) => {
  const { route, category, date } = req.query;

  try {
    if (route && category && date) {
      const sql = `
  SELECT id, name, version,
         DATE_FORMAT(effective_from, '%Y-%m-%d') AS effective_from
    FROM price_lists
   WHERE route_id = ?
     AND category_id = ?
     AND effective_from <= DATE(?)
   ORDER BY effective_from DESC
`;
      const { rows } = await db.query(sql, [route, category, date]);
      return res.json(rows);            // ← IMPORTANT: return
   }

    const sqlAll = `
  SELECT id, name, version,
         DATE_FORMAT(effective_from, '%Y-%m-%d') AS effective_from,
         route_id, category_id, created_by, created_at
    FROM price_lists
   ORDER BY effective_from DESC
`;
    const { rows: allRows } = await db.query(sqlAll);
    return res.json(allRows);           // ← și aici return (opțional, dar curat)
  } catch (err) {
    console.error('[GET /api/price-lists]', err);
    res.status(500).json({ error: 'Eroare server' });
  }
});



// ✅ GET /api/price-lists/:id/items — CITIRE pentru admin/op_admin/agent/driver
router.get('/price-lists/:id/items', requireAuth, requireRole('admin','operator_admin','agent','driver'), async (req, res) => {
  const listId = Number(req.params.id);
  try {
    const routeRes = await db.query('SELECT route_id FROM price_lists WHERE id = ?', [listId]);
    const routeId = routeRes.rows?.[0]?.route_id ?? null;

    const sql = `
  SELECT
    pli.id,
    pli.price_list_id,
    pl.route_id,
    pli.from_station_id,
    s1.name AS from_stop,
    pli.to_station_id,
    s2.name AS to_stop,
    pli.price,
    pli.price_return,
    pli.currency
  FROM price_list_items pli
  JOIN price_lists pl ON pl.id = pli.price_list_id
  LEFT JOIN stations s1 ON s1.id = pli.from_station_id
  LEFT JOIN stations s2 ON s2.id = pli.to_station_id
  WHERE pli.price_list_id = ?
  ORDER BY s1.name, s2.name, pli.id
`;
    const { rows } = await db.query(sql, [listId]);
    res.json(rows);
  } catch (err) {
    console.error('[GET /api/price-lists/:id/items]', err);
    res.status(500).json({ error: 'Eroare server' });
  }
});

// ✅ POST /api/price-lists — SCRIERE doar admin/op_admin
router.post('/price-lists', requireAuth, requireRole('admin','operator_admin'), async (req, res) => {
  const { route, category, effective_from, name, version, items, created_by } = req.body;

  if (!route || !category || !created_by) {
    return res.status(400).json({ error: 'route, category și created_by sunt obligatorii' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [exist] = await conn.execute(
      `SELECT id FROM price_lists
    WHERE route_id=? AND category_id=? AND effective_from=DATE(?)
    LIMIT 1`,
      [route, category, effective_from]
    );

    let listId;
    if (exist.length) {
      listId = exist[0].id;
      await conn.execute('UPDATE price_lists SET name=?, version=? WHERE id=?', [name, version, listId]);
      await conn.execute('DELETE FROM price_list_items WHERE price_list_id=?', [listId]);
    } else {
      const [insert] = await conn.execute(
        `INSERT INTO price_lists
     (name, version, effective_from, route_id, category_id, created_by)
   VALUES (?, ?, DATE(?), ?, ?, ?)`,
        [name, version, effective_from, route, category, created_by]
      );
      listId = insert.insertId;
    }

    // mapare stații
    const [stations] = await conn.execute(`
      SELECT s.id AS station_id, s.name
        FROM route_stations rs
        JOIN stations s ON s.id = rs.station_id
       WHERE rs.route_id = ?`,
      [route]
    );
    const map = new Map();
    stations.forEach(r => map.set(r.name, r.station_id));

    for (const it of items) {
      const from_station_id = it.from_station_id ?? map.get(it.from_stop ?? '') ?? null;
      const to_station_id = it.to_station_id ?? map.get(it.to_stop ?? '') ?? null;
      // insert items (cu currency din schemă)
      await conn.execute(
        `INSERT INTO price_list_items
     (price_list_id, from_station_id, to_station_id, price, price_return, currency)
   VALUES (?, ?, ?, ?, ?, ?)`,
        [listId, from_station_id, to_station_id, it.price, it.price_return ?? null, it.currency ?? 'RON']
      );
    }

    await conn.commit();
    res.json({ id: listId });
  } catch (err) {
    await conn.rollback();
    console.error('[POST /api/price-lists]', err);
    res.status(500).json({ error: 'Eroare server' });
  } finally {
    conn.release();
  }
});

// ✅ PUT /api/price-lists/:id — SCRIERE doar admin/op_admin
router.put('/price-lists/:id', requireAuth, requireRole('admin','operator_admin'), async (req, res) => {
  const listId = req.params.id;
  const { effective_from, name, version, items } = req.body;

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
await conn.execute(
  `UPDATE price_lists
      SET name=?,
          version=?,
          effective_from=DATE(?)
    WHERE id=?`,
  [name, version, effective_from, listId]
);

    await conn.execute('DELETE FROM price_list_items WHERE price_list_id=?', [listId]);

    const [rRoute] = await conn.execute('SELECT route_id FROM price_lists WHERE id=?', [listId]);
    const routeId = rRoute[0]?.route_id;

    const [stations] = await conn.execute(`
      SELECT s.id AS station_id, s.name
        FROM route_stations rs
        JOIN stations s ON s.id = rs.station_id
       WHERE rs.route_id = ?`,
      [routeId]
    );
    const map = new Map();
    stations.forEach(r => map.set(r.name, r.station_id));

    for (const it of items) {
      const from_station_id = it.from_station_id ?? map.get(it.from_stop ?? '') ?? null;
      const to_station_id = it.to_station_id ?? map.get(it.to_stop ?? '') ?? null;
await conn.execute(
  `INSERT INTO price_list_items
     (price_list_id, from_station_id, to_station_id, price, price_return, currency)
   VALUES (?, ?, ?, ?, ?, ?)`,
  [listId, from_station_id, to_station_id, it.price, it.price_return ?? null, it.currency ?? 'RON']
);
    }

    await conn.commit();
    res.sendStatus(204);
  } catch (err) {
    await conn.rollback();
    console.error('[PUT /api/price-lists/:id]', err);
    res.status(500).json({ error: 'Eroare server' });
  } finally {
    conn.release();
  }
});

// ✅ DELETE /api/price-lists/:id — SCRIERE doar admin/op_admin
router.delete('/price-lists/:id', requireAuth, requireRole('admin','operator_admin'), async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('DELETE FROM price_list_items WHERE price_list_id=?', [id]);
    await db.query('DELETE FROM price_lists WHERE id=?', [id]);
    res.sendStatus(204);
  } catch (err) {
    console.error('[DELETE /api/price-lists/:id]', err);
    res.status(500).json({ error: 'Eroare server' });
  }
});

// ✅ POST /api/price-lists/:id/copy-opposite — SCRIERE doar admin/op_admin
router.post('/price-lists/:id/copy-opposite', requireAuth, requireRole('admin','operator_admin'), async (req, res) => {
  const srcId = req.params.id;
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

const [srcRows] = await conn.execute(
  `SELECT route_id, category_id, effective_from, name, version, created_by
     FROM price_lists WHERE id=?`,
  [srcId]
);
    if (!srcRows.length) {
      await conn.rollback();
      return res.status(404).json({ error: 'Lista sursă inexistentă' });
    }

    const src = srcRows[0];
    const [oppRows] = await conn.execute('SELECT opposite_route_id FROM routes WHERE id=?', [src.route_id]);
    const oppRoute = oppRows[0]?.opposite_route_id;
    if (!oppRoute) {
      await conn.rollback();
      return res.status(400).json({ error: 'Ruta opusă nu este definită' });
    }

const [exist] = await conn.execute(
  `SELECT id FROM price_lists
     WHERE route_id=? AND category_id=? AND effective_from=DATE(?)
     LIMIT 1`,
  [oppRoute, src.category_id, src.effective_from]
);

    let newListId;
    if (exist.length) {
      newListId = exist[0].id;
      await conn.execute('UPDATE price_lists SET name=?, version=? WHERE id=?', [src.name, src.version, newListId]);
      await conn.execute('DELETE FROM price_list_items WHERE price_list_id=?', [newListId]);
    } else {
const [insert] = await conn.execute(
  `INSERT INTO price_lists
     (name, version, effective_from, route_id, category_id, created_by)
   VALUES (?, ?, DATE(?), ?, ?, ?)`,
  [src.name, src.version, src.effective_from, oppRoute, src.category_id, src.created_by]
);
      newListId = insert.insertId;
    }

    const [items] = await conn.execute(
      'SELECT from_station_id, to_station_id, price, price_return FROM price_list_items WHERE price_list_id=?',
      [srcId]
    );

    for (const { from_station_id, to_station_id, price, price_return } of items) {
await conn.execute(
  `INSERT INTO price_list_items
     (price_list_id, from_station_id, to_station_id, price, price_return, currency)
   VALUES (?, ?, ?, ?, ?, ?)`,
  [newListId, to_station_id, from_station_id, price, price_return, 'RON']
);
    }

    await conn.commit();
    res.json({ id: newListId });
  } catch (err) {
    await conn.rollback();
    console.error('[POST /api/price-lists/:id/copy-opposite]', err);
    res.status(500).json({ error: 'Eroare server' });
  } finally {
    conn.release();
  }
});

module.exports = router;
