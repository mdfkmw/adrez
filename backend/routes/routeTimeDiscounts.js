const express = require('express');
const db      = require('../db');
const router  = express.Router();


/**
 * GET /api/routes/:routeId/discounts?time=HH:MM
 * Returnează lista de tipuri de discount (id, code, label, percent_off)
 * valabile pentru combinația routeId + time
 */
// routes/routeTimeDiscounts.js
router.get('/routes/:routeId/discounts', async (req, res) => {
  const { routeId } = req.params;
  const { time }    = req.query;            // ex: '06:00' sau '06:00:00'
      // citim asocierile din noul tabel route_schedule_discounts
  const { rows } = await db.query(
    `SELECT dt.id,
            dt.code,
            dt.label,
            dt.value_off     AS discount_value,
            dt.type          AS discount_type
       FROM route_schedule_discounts rsd
       JOIN discount_types dt
         ON dt.id = rsd.discount_type_id
       JOIN route_schedules rs
         ON rs.id = rsd.route_schedule_id
      WHERE rs.route_id = $1
        AND to_char(rs.departure, 'HH24:MI') = $2
      ORDER BY dt.label`,
    [routeId, time]
 );

    res.json(rows);
});


/**
 * PUT /api/routes/:routeId/discounts
 * Body: { time: 'HH:MM', discountTypeIds: [1,3,5] }
 * Actualizează (într-o tranzacție) setul de discount-uri aplicabile
 * pentru routeId + time.
 */
router.put('/routes/:routeId/discounts', async (req, res) => {
    const { routeId }         = req.params;
    const { time, discountTypeIds } = req.body;
    if (!time || !Array.isArray(discountTypeIds)) {
      return res.status(400).json({ error: 'Trebuie să trimiți time și discountTypeIds ca array' });
    }
    const client = await db.connect();
    try {
      await client.query('BEGIN');
            // Mai întâi ștergem toate asocierile vechi pentru ruta+ora asta
      await client.query(
        `DELETE FROM route_schedule_discounts
           USING route_schedules rs
          WHERE rs.id                = route_schedule_discounts.route_schedule_id
            AND rs.route_id         = $1
            AND rs.departure        = $2`,
        [routeId, time]
      );
      // Apoi inserăm noile asocieri
      // (găsim întâi id‑ul schedule-ului potrivit)
      const { rows: sched } = await client.query(
        `SELECT id
           FROM route_schedules
          WHERE route_id = $1
            AND departure = $2`,
        [routeId, time]
      );
      if (sched[0]) {
        const rsId = sched[0].id;
        for (const dtId of discountTypeIds) {
          await client.query(
            `INSERT INTO route_schedule_discounts
               (route_schedule_id, discount_type_id)
             VALUES ($1, $2)
             ON CONFLICT DO NOTHING`,
            [rsId, dtId]
          );
        }
      }
     await client.query('COMMIT');
      res.sendStatus(204);
    } catch (err) {
      await client.query('ROLLBACK');
      console.error(err);
      res.status(500).json({ error: 'Eroare la salvarea reducerilor pentru route+time' });
    } finally {
      client.release();
    }
  }
);

module.exports = router;
