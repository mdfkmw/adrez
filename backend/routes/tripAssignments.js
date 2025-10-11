const express = require('express');
const db = require('../db');
const router = express.Router();

// GET /api/trip_assignments?date=YYYY-MM-DD
// se aduce si se separa per operator in functie de route_schedules
router.get('/', async (req, res) => {
  const { date, operator_id } = req.query;
  try {
    const query = `
      SELECT
        tv.id              AS trip_vehicle_id,
        tv.trip_id,
        tv.is_primary,
        t.time             AS trip_time,
        t.disabled       AS disabled,
        t.route_id,
        r.name             AS route_name,
        rs.direction,
        v.id               AS vehicle_id,
        v.name             AS vehicle_name,
        v.plate_number,
        tve.employee_id,
        e.name             AS employee_name
      FROM trip_vehicles tv
      JOIN trips t              ON t.id = tv.trip_id
      JOIN routes r             ON r.id = t.route_id
      JOIN vehicles v           ON v.id = tv.vehicle_id
      JOIN route_schedules rs   ON rs.route_id = r.id AND rs.departure = t.time
      LEFT JOIN trip_vehicle_employees tve ON tve.trip_vehicle_id = tv.id
      LEFT JOIN employees e     ON e.id = tve.employee_id
      WHERE t.date = $1 AND rs.operator_id = $2
      ORDER BY rs.direction, t.time, tv.is_primary DESC, tv.id;
    `;
    const { rows } = await db.query(query, [date, operator_id]);
    res.json(rows);
  } catch (err) {
    console.error('GET /api/trip_assignments error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});
;


// POST /api/trip_assignments
// Body: { trip_vehicle_id: number, employee_id: number | null }
router.post('/', async (req, res) => {
  console.log('[POST /trip_assignments] body =', req.body);
  const { trip_vehicle_id, employee_id } = req.body;

  if (!trip_vehicle_id) {
    return res.status(400).json({ error: 'trip_vehicle_id missing' });
  }

  try {
    if (employee_id === null || employee_id === '' || employee_id === undefined) {
      // ───────────────  UNASSIGN  ───────────────
      await db.query(
        'DELETE FROM trip_vehicle_employees WHERE trip_vehicle_id = $1',
        [trip_vehicle_id]
      );
      console.log('▶ ASIGNARE ștearsă');
      return res.json({ success: true, unassigned: true });
    }

    // ───────────────  ASSIGN / UPDATE  ───────────────
    await db.query(
      `
      INSERT INTO trip_vehicle_employees (trip_vehicle_id, employee_id)
      VALUES ($1, $2)
      ON CONFLICT (trip_vehicle_id) DO UPDATE
        SET employee_id = EXCLUDED.employee_id
      `,
      [trip_vehicle_id, employee_id]
    );
    console.log('▶ SALVARE REUȘITĂ, returnăm success');
    res.json({ success: true, assigned: true });

  } catch (err) {
    console.error('POST /api/trip_assignments error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});


module.exports = router;
