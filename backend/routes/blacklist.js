const express = require('express');
const router = express.Router();
const db = require('../db');

// ✅ Adaugă persoană în blacklist
router.post('/blacklist', async (req, res) => {
  const { person_id, reason } = req.body;

  // Hardcodează employee_id
  const employee_id = 12;





  if (!person_id) {
    return res.status(400).json({ error: 'person_id lipsă' });
  }

  try {
    const existing = await db.query(
      'SELECT id FROM blacklist WHERE person_id = $1',
      [person_id]
    );
    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'Persoana este deja în blacklist' });
    }

    await db.query(
      'INSERT INTO blacklist (person_id, reason, added_by_employee_id) VALUES ($1, $2, $3)',
      [person_id, reason || '', employee_id]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('Eroare blacklist:', err);
    res.status(500).json({ error: 'Eroare server' });
  }
});

// ✅ Marchează neprezentare
router.post('/no-shows', async (req, res) => {
  const { reservation_id } = req.body;
  //hardocare employee_id
  const employee_id = 12;

  if (!reservation_id) {
    return res.status(400).json({ error: 'reservation_id missing' });
  }

  // 1. Preluăm datele rezervării
  const rRes = await db.query(
    `SELECT person_id, trip_id, seat_id, board_station_id, exit_station_id
       FROM reservations
      WHERE id = $1`,
    [reservation_id]
  );
  if (rRes.rowCount !== 1) {
    return res.status(404).json({ error: 'reservation not found' });
  }
  const { person_id, trip_id, seat_id, board_station_id, exit_station_id } = rRes.rows[0];

  // 2. Inserăm marcajul no-show doar pentru rezervarea specifică
  await db.query(
    `INSERT INTO no_shows
       (reservation_id, person_id, trip_id, seat_id, board_station_id, exit_station_id, added_by_employee_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7)
     ON CONFLICT (reservation_id) DO NOTHING`,
    [
      reservation_id,
      person_id,
      trip_id,
      seat_id,
      board_station_id,
      exit_station_id,
      employee_id
    ]
  );

  res.json({ success: true });
});



// ─── Verifică blacklist + ultimele 5 neprezentări pentru un telefon ───
router.get('/blacklist/check', async (req, res) => {
  // normalizăm telefonul: păstrăm doar cifrele
  const rawPhone = req.query.phone || '';
  const digits = rawPhone.replace(/\D/g, '');

  // dacă sunt < 10 cifre, nu căutăm încă
  if (digits.length < 10) {
    return res.json({ blacklisted: false, reason: null, blacklist_history: [], no_shows: [] });
  }

  try {
    // 1) găsește persoana comparând la nivel de cifre (indiferent de spații, +, etc.)
    const personRes = await db.query(
      "SELECT id FROM people WHERE regexp_replace(phone, '\\D', '', 'g') = $1",
      [digits]
    );
    if (personRes.rows.length === 0) {
      // nu există persoana -> nu e în blacklist și n-are no-shows
      return res.json({ blacklisted: false, reason: null, blacklist_history: [], no_shows: [] });
    }

    const person_id = personRes.rows[0].id;

    // 2) verifică blacklist (ultimul motiv + istoric)
    const blRes = await db.query(
      'SELECT created_at, reason FROM blacklist WHERE person_id = $1 ORDER BY created_at DESC LIMIT 1',
      [person_id]
    );

    const blHistoryRes = await db.query(
      `SELECT created_at, reason
         FROM blacklist
        WHERE person_id = $1
     ORDER BY created_at DESC
        LIMIT 5`,
      [person_id]
    );

    // 3) ultimele 10 no-shows (pe ID-uri de stații)
    const showsRes = await db.query(
      `SELECT
         TO_CHAR(ns.created_at, 'DD.MM.YYYY') AS date,
         TO_CHAR(t.time, 'HH24:MI')           AS hour,
         r.name                               AS route_name,
         ns.board_station_id                  AS board_station_id,
         ns.exit_station_id                   AS exit_station_id,
         ns.trip_id
       FROM no_shows ns
       JOIN trips  t ON t.id = ns.trip_id
       JOIN routes r ON r.id = t.route_id
      WHERE ns.person_id = $1
      ORDER BY ns.created_at DESC
      LIMIT 10`,
      [person_id]
    );

    return res.json({
      person_id,
      blacklisted: blRes.rows.length > 0,
      reason: blRes.rows[0]?.reason || null,
      blacklist_history: blHistoryRes.rows,
      no_shows: showsRes.rows
    });
  } catch (err) {
    console.error('Eroare la blacklist/check:', err);
    return res.status(500).json({ error: 'server error' });
  }
});


// ─── Listare combinate: blacklist + cei marcați neprezentări ───
router.get('/blacklist', async (req, res) => {
  try {
    const result = await db.query(`
       WITH blacklist_data AS (
         SELECT bl.id          AS blacklist_id,
                p.id           AS person_id,
                p.name         AS person_name,
                p.phone,
                e.name         AS added_by_employee,
                bl.reason      AS reason,
                TO_CHAR(bl.created_at,'DD.MM.YYYY HH24:MI') AS added_at,
                'blacklist'    AS source
           FROM blacklist bl
       JOIN people p ON p.id = bl.person_id
       LEFT JOIN employees e ON e.id = bl.added_by_employee_id
       ),
       no_show_data AS (
         SELECT
           NULL::int               AS blacklist_id,
           p.id                    AS person_id,
           p.name                  AS person_name,
           p.phone,
           e2.name                 AS added_by_employee,
           CONCAT('Neprezentări: ', COUNT(*)) AS reason,
           TO_CHAR(MAX(ns.created_at),'DD.MM.YYYY HH24:MI') AS added_at,
           'no_show'               AS source
         FROM no_shows ns
         JOIN people p ON p.id = ns.person_id
         JOIN employees e2 ON e2.id = ns.added_by_employee_id
         LEFT JOIN blacklist bl ON bl.person_id = p.id
        WHERE bl.id IS NULL
        GROUP BY p.id, p.name, p.phone, e2.name
       )
 SELECT * FROM blacklist_data
 UNION
 SELECT * FROM no_show_data
       ORDER BY added_at DESC NULLS LAST;
     `);
    res.json(result.rows);
  } catch (err) {
    console.error('Eroare la listare blacklist:', err);
    res.status(500).json({ error: 'server error' });
  }
});






// ─── Ștergere intrare blacklist după ID ───
router.delete('/blacklist/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const del = await db.query(
      'DELETE FROM blacklist WHERE id = $1 RETURNING *',
      [id]
    );
    if (del.rows.length === 0) {
      return res.status(404).json({ error: 'Blacklist entry not found' });
    }
    res.json({ success: true });
  } catch (err) {
    console.error('Eroare la ștergere blacklist:', err);
    res.status(500).json({ error: 'server error' });
  }
});




// DELETE all no-shows for o persoană
router.delete('/no-shows/:person_id', async (req, res) => {
  const { person_id } = req.params;
  try {
    await db.query(
      'DELETE FROM no_shows WHERE person_id = $1',
      [person_id]
    );
    res.json({ success: true });
  } catch (err) {
    console.error('Eroare la ștergere neprezentări:', err);
    res.status(500).json({ error: 'server error' });
  }
});





//Pentru a “gri-out” automat rezervările deja marcate drept neprezentate
// GET /api/no-shows/:tripId → [reservation_id, ...]
router.get('/no-shows/:tripId', async (req, res) => {
  const tripId = parseInt(req.params.tripId, 10);
  try {
    const { rows } = await db.query(
      `SELECT reservation_id
         FROM no_shows
        WHERE trip_id = $1`,
      [tripId]
    );
    // trimitem array-ul de ID-uri
    res.json(rows.map(r => r.reservation_id));
  } catch (err) {
    console.error('Eroare la GET /no-shows/:tripId', err);
    res.status(500).json({ error: 'server error' });
  }
});







module.exports = router;
