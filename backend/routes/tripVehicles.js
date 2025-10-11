// Backend/routes/tripVehicles.js
const express = require('express');
const pool    = require('../db');

const router = express.Router({ mergeParams: true });

// GET  /api/trips/:tripId/vehicles
router.get('/', async (req, res) => {
  const { tripId } = req.params;
  try {
    const { rows } = await pool.query(
      `SELECT
         tv.id           AS trip_vehicle_id,
         tv.vehicle_id,
         tv.is_primary,
         v.name,
         v.plate_number
       FROM trip_vehicles tv
       JOIN vehicles v ON v.id = tv.vehicle_id
       WHERE tv.trip_id = $1
       ORDER BY tv.is_primary DESC, tv.id`,
      [tripId]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Eroare la listarea vehiculelor cursei' });
  }
});

// POST /api/trips/:tripId/vehicles
// body: { vehicle_id: number, is_primary?: boolean }
router.post('/', async (req, res) => {
  const { tripId } = req.params;
  const { vehicle_id, is_primary = false } = req.body;
  try {
    if (is_primary) {
      // demarcăm toate celelalte ca false
      await pool.query(
        'UPDATE trip_vehicles SET is_primary = FALSE WHERE trip_id = $1',
        [tripId]
      );
    }
    const { rows } = await pool.query(
      `INSERT INTO trip_vehicles(trip_id, vehicle_id, is_primary)
       VALUES ($1, $2, $3)
       RETURNING id AS trip_vehicle_id, vehicle_id, is_primary`,
      [tripId, vehicle_id, is_primary]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Eroare la adăugarea vehiculului în cursă' });
  }
});


// DELETE /api/trips/:tripId/vehicles/:tvId
router.delete('/:tvId', async (req, res) => {
  const { tripId, tvId } = req.params;

  // 1. Verifică dacă există rezervări active pe vehiculul curent
  const check = await pool.query(`
    SELECT 1
      FROM reservations r
      JOIN seats s ON r.seat_id = s.id
     WHERE r.trip_id = $1
       AND s.vehicle_id = (
         SELECT vehicle_id
           FROM trip_vehicles
          WHERE id = $2
       )
       AND r.status = 'active'
     LIMIT 1
  `, [tripId, tvId]);

  if (check.rows.length) {
    return res.status(400).json({
      error: 'Există rezervări active pe acest vehicul; nu poate fi șters.'
    });
  }

  // 2. Dacă nu există rezervări, șterge dublura
  await pool.query(
    'DELETE FROM trip_vehicles WHERE id = $1',
    [tvId]
  );

  res.json({ success: true });
});
;



// PATCH /api/trips/:tripId/vehicles/:tvId
// Înlocuieşte un vehicul (trip_vehicle) şi migrează rezervările active
// backend/routes/tripVehicles.js

// ⬇️ router declarat în app.js:
// app.use('/api/trips/:tripId/vehicles', tripVehiclesRouter);

router.patch('/:tvId', async (req, res, next) => {
  const { tripId, tvId }  = req.params;          // ← ambele există (vin din ruta-părinte + /:tvId)
  const { newVehicleId }  = req.body;

  let client;
  try {
    client = await pool.connect();

    /* 1. Citim vehiculul curent + is_primary (UN singur SELECT) */
    const { rows: [tv] } = await client.query(
      `SELECT vehicle_id, is_primary
         FROM trip_vehicles
        WHERE id = $1
          FOR UPDATE`,                         
      [tvId]
    );
    if (!tv) return res.status(404).json({ error: 'Legătura trip_vehicle inexistentă.' });

    /* 2. Dacă noul vehicul este acelaşi, ieşim imediat – nimic de făcut */
    if (Number(tv.vehicle_id) === Number(newVehicleId))
      return res.status(204).end();

    /* 3. Verificăm locurile rezervărilor pe noul vehicul */
    const { rows: reservations } = await client.query(
      `SELECT r.id, s.label
         FROM reservations r
         JOIN seats s ON r.seat_id = s.id
        WHERE r.trip_id    = $1
          AND s.vehicle_id = $2
          AND r.status     = 'active'`,
      [tripId, tv.vehicle_id]
    );

    const { rows: missingSeats } = await client.query(
      `SELECT label
         FROM unnest($1::text[]) AS l(label)
   LEFT JOIN seats s
           ON s.vehicle_id = $2
          AND s.label      = l.label
        WHERE s.id IS NULL`,
      [reservations.map(r => r.label), newVehicleId]
    );
    if (missingSeats.length)
      return res.status(400).json({
        error: `Vehiculul nou nu are locurile: ${missingSeats.map(r => r.label).join(', ')}.`
      });

    /* 4. Tranzacţia reală */
    await client.query('BEGIN');

    /* 4.a. Mutăm rezervările */
    for (const { id: resId, label } of reservations) {
      const { rows: [{ id: newSeatId }] } = await client.query(
        'SELECT id FROM seats WHERE vehicle_id = $1 AND label = $2',
        [newVehicleId, label]
      );
      await client.query(
        'UPDATE reservations SET seat_id = $1 WHERE id = $2',
        [newSeatId, resId]
      );
    }

    /* 4.b. Actualizăm trip_vehicles (AICI era problema principală) */
    await client.query(
      'UPDATE trip_vehicles SET vehicle_id = $1 WHERE id = $2',
      [newVehicleId, tvId]
    );

    /* 4.c. Dacă rândul era principal, sincronizăm şi tabela trips */
    if (tv.is_primary) {
      await client.query(
        'UPDATE trips SET vehicle_id = $1 WHERE id = $2',
        [newVehicleId, tripId]
      );
    }

    await client.query('COMMIT');

    /* 5. Returnăm rândul modificat */
    const { rows: [updated] } = await client.query(
      `SELECT id        AS trip_vehicle_id,
              trip_id,
              vehicle_id,
              is_primary
         FROM trip_vehicles
        WHERE id = $1`,
      [tvId]
    );
    res.json(updated);

  } catch (err) {
    if (client) await client.query('ROLLBACK');
    next(err);
  } finally {
    if (client) client.release();
  }
});
;
;


module.exports = router;
