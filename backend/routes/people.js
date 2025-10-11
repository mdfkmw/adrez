// routes/people.js
const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /api/people/history
router.get('/history', async (req, res) => {
  const { phone } = req.query;
  if (!phone) return res.status(400).json({ error: 'phone missing' });

  try {
    // 1️⃣ găsește persoana
    const pRes = await db.query(
      'SELECT id, name, phone FROM people WHERE phone = $1',
      [phone]
    );
    if (pRes.rows.length === 0) {
      return res.json({ exists: false });
    }
    const person = pRes.rows[0];

    // 2️⃣ ultimele 5 rezervări
    const rRes = await db.query(
      `SELECT
         r.board_station_id,
         r.exit_station_id,
         t.date,
         t.time,
         rt.name   AS route_name,
         s.label   AS seat_label
       FROM reservations r
       JOIN trips    t  ON t.id   = r.trip_id
       JOIN routes   rt ON rt.id  = t.route_id
       JOIN seats    s  ON s.id   = r.seat_id
       WHERE r.person_id = $1
         AND r.status    = 'active'
       ORDER BY t.date DESC, t.time DESC
       LIMIT 5`,
      [person.id]
    );

    res.json({
      exists: true,
      name: person.name,
      history: rRes.rows
    });
  } catch (err) {
    console.error('Error /api/people/history:', err);
    res.status(500).json({ error: 'server error' });
  }
});



router.get('/:id/report', async (req, res) => {
  const { id } = req.params;

  try {
    // 1️⃣ Preluăm și numele pasagerului
    const personRes = await db.query(
      'SELECT name FROM people WHERE id = $1',
      [id]
    );
    const personName = personRes.rows[0]?.name || '';

    // 2️⃣ Rezervări + label + created_at
    const reservationsRes = await db.query(
      `SELECT
         r.id,
         s.label        AS seat_label,
         t.date,
         t.time,
         rt.name        AS route_name,
         r.board_station_id,
         r.exit_station_id,
         r.reservation_time
       FROM reservations r
       JOIN trips   t   ON r.trip_id   = t.id
       JOIN routes  rt  ON t.route_id  = rt.id
       JOIN seats   s   ON r.seat_id   = s.id
       WHERE r.person_id = $1
       ORDER BY t.date DESC, t.time DESC`,
      [id]
    );

  // 3️⃣ Neprezentări (inclusiv locul rezervat)
// 3️⃣ Istoric neprezentări (grupate pe cursă)
const noShowsRes = await db.query(
  `SELECT
     to_char(t.date, 'DD.MM.YYYY')   AS date,
     to_char(t.time, 'HH24:MI')      AS time,
     rt.name                         AS route_name,
     array_agg(s.label ORDER BY s.label) AS seats
   FROM no_shows ns
   JOIN reservations r
     ON ns.reservation_id = r.id
   JOIN trips   t
     ON r.trip_id = t.id
   JOIN routes  rt
     ON t.route_id = rt.id
   JOIN seats   s
     ON r.seat_id = s.id
   WHERE ns.person_id = $1
   GROUP BY t.date, t.time, rt.name
   ORDER BY t.date DESC, t.time DESC`,
  [id]
);


    // 4️⃣ Blacklist (dacă există)
    const blacklistRes = await db.query(
      `SELECT reason, added_by_employee_id, created_at
       FROM blacklist
       WHERE person_id = $1
       LIMIT 1`,
      [id]
    );

    // 5️⃣ Trimitem JSON-ul complet
    res.json({
      personName,
      reservations: reservationsRes.rows    || [],
      noShows:      noShowsRes.rows         || [],
      blacklist:    blacklistRes.rows[0]   || null
    });

  } catch (err) {
    console.error('Eroare la /api/people/:id/report:', err);
    res.status(500).json({ error: 'Eroare la generarea raportului' });
  }
});


module.exports = router;
