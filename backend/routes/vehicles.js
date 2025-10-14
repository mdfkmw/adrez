const express = require('express');
const router = express.Router();
const db = require('../db');

/* ================================================================
   GET /api/vehicles
   Listare completă vehicule
   ================================================================ */
router.get('/', async (_req, res) => {
  try {
    const { rows } = await db.query('SELECT * FROM vehicles');
    res.json(rows);
  } catch (err) {
    console.error('Eroare la fetch vehicles:', err);
    res.status(500).json({ error: 'Eroare la fetch vehicles' });
  }
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

module.exports = router;
