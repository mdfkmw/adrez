// Importă framework-ul Express pentru a crea rute HTTP
const express = require('express');
// Creează un router Express pentru a defini rutele API
// Creează un router Express pentru a defini rutele disponibile în această secțiune
const router = express.Router();
// Importă conexiunea la baza de date (modulul db)
const db = require('../db');
const pool = require('../db');    // <— adaugă această linie







// GET /api/trips?date=YYYY-MM-DD
router.get('/', async (req, res) => {
  const { date } = req.query;
  try {
    let where = '';
    let params = [];
    if (date) {
      where = 'WHERE t.date = $1';
      params.push(date);
    }
    const query = `
  SELECT 
    t.id            AS trip_id,
    t.date,
    t.time,
    t.route_id,
    t.vehicle_id,
    rs.operator_id  AS trip_operator_id,
    r.name          AS route_name,
    v.name          AS vehicle_name,
    v.plate_number,
    v.operator_id   AS vehicle_operator_id
  FROM trips t
  JOIN routes r ON t.route_id = r.id
  JOIN route_schedules rs ON rs.route_id = t.route_id AND rs.departure = t.time
  JOIN vehicles v ON t.vehicle_id = v.id
  ${where}
  ORDER BY t.time ASC
`;




    const result = await db.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Eroare la GET /api/trips:', err);
    res.status(500).json({ error: 'Eroare internă trips' });
  }
});

























// 🔹 Endpoint: Rezumat curse (folosit pentru dropdown backupuri)
// Definește ruta GET (ex: listare date)
// Definește o rută GET - folosită pentru a obține date din server
router.get('/summary', async (req, res) => {
  // Folosește blocul try pentru a prinde eventualele erori
  // Începe un bloc try-catch pentru tratarea erorilor
  // Combină tabele SQL pentru a obține date corelate din mai multe surse
  // Combină tabele SQL pentru a obține date corelate din mai multe surse
  try {
    const query = `
      SELECT t.id AS trip_id, t.date, t.time, r.name AS route_name, v.plate_number
      FROM trips t

      JOIN routes r ON t.route_id = r.id

      LEFT JOIN vehicles v ON t.vehicle_id = v.id
      ORDER BY t.date DESC, t.time ASC
    `;
    // Execută o interogare SQL folosind conexiunea la baza de date
    // Execută o interogare în PostgreSQL folosind modulul 'db'
    const result = await db.query(query);
    // Trimite răspunsul înapoi către client sub formă de JSON
    res.json(result.rows);
    // Prinde orice eroare apărută în blocul try și o tratează corespunzător
  } catch (err) {
    // Afișează o eroare în consola backend-ului pentru depanare
    console.error('Eroare la /summary:', err);
    // Răspunde clientului cu un cod de stare HTTP și un mesaj JSON
    res.status(500).json({ error: 'Eroare la încărcarea tripurilor' });
  }
});

// 🔹 Găsește sau creează automat o cursă (trip)
router.get('/find', async (req, res) => {
  // primim fie schedule_id direct, fie route_id + time
  let { schedule_id, route_id, date, time } = req.query;

  try {
    // dacă nu e furnizat schedule_id, îl determinăm din route_id + time
    if (!schedule_id) {
      const schedRes = await db.query(
        `SELECT id, operator_id, departure
           FROM route_schedules
          WHERE route_id  = $1
            AND departure = $2
          LIMIT 1`,
        [route_id, time]
      );
      if (!schedRes.rowCount) {
        return res.status(404).json({ error: 'Programare inexistentă' });
      }
      schedule_id = schedRes.rows[0].id;
      time = schedRes.rows[0].departure;
      route_id = Number(route_id);            // coerce la number dacă e string
      var operator_id = schedRes.rows[0].operator_id;
    } else {
      // dacă avem schedule_id, aducem și operator_id + departure
      const schedRes = await db.query(
        `SELECT operator_id, departure
           FROM route_schedules
          WHERE id = $1
          LIMIT 1`,
        [schedule_id]
      );
      if (!schedRes.rowCount) {
        return res.status(404).json({ error: 'Programare inexistentă' });
      }
      operator_id = schedRes.rows[0].operator_id;
      time = schedRes.rows[0].departure;
    }

    // căutăm trip-ul deja creat pentru acea zi + schedule
    const findRes = await db.query(
      `SELECT * 
         FROM trips
        WHERE route_schedule_id = $1
          AND date              = $2
          AND disabled          = false`,
      [schedule_id, date]
    );
    if (findRes.rowCount > 0) {
      return res.json(findRes.rows[0]);
    }

    // nu există: alegem vehiculul default pentru operator
    const vehRes = await db.query(
      `SELECT id FROM vehicles WHERE operator_id = $1 LIMIT 1`,
      [operator_id]
    );
    if (!vehRes.rowCount) {
      return res.status(404).json({ error: 'Vehicul default inexistent' });
    }
    const defaultVehicleId = vehRes.rows[0].id;

    // inserăm noul trip, cu legătură spre schedule
    const insertRes = await db.query(
      `INSERT INTO trips
         (route_schedule_id, route_id, vehicle_id, date, time)
       VALUES ($1,               $2,       $3,         $4,   $5)
       RETURNING *`,
      [schedule_id, route_id, defaultVehicleId, date, time]
    );

    // populăm și tabelul trip_vehicles
    await db.query(
      `INSERT INTO trip_vehicles (trip_id, vehicle_id, is_primary)
       VALUES ($1,       $2,         $3)`,
      [insertRes.rows[0].id, defaultVehicleId, true]
    );

    // trimitem trip-ul creat
    res.json(insertRes.rows[0]);

  } catch (err) {
    console.error('Eroare la găsire/creare trip:', err);
    res.status(500).json({ error: 'Eroare internă' });
  }
});
;


// PATCH /api/trips/:id/vehicle
router.patch('/:id/vehicle', async (req, res) => {
  const tripId = req.params.id;
  const { newVehicleId } = req.body;

  // 1. Preia vechiul vehicle_id din trips
  const { rows: tripRows } = await pool.query(
    'SELECT vehicle_id FROM trips WHERE id = $1',
    [tripId]
  );
  if (!tripRows.length) {
    return res.status(404).json({ error: 'Cursa nu există.' });
  }
  const oldVehicleId = tripRows[0].vehicle_id;

  // 2. Ia toate rezervările active pe cursa asta și vehiculul vechi
  const { rows: reservations } = await pool.query(
    `SELECT r.id, s.label
       FROM reservations r
       JOIN seats s ON r.seat_id = s.id
      WHERE r.trip_id    = $1
        AND s.vehicle_id = $2
        AND r.status     = 'active'`,
    [tripId, oldVehicleId]
  );

  // 3. Verifică dacă toate label-urile există pe vehiculul nou
  const missing = [];
  for (let { label } of reservations) {
    const { rowCount } = await pool.query(
      'SELECT 1 FROM seats WHERE vehicle_id = $1 AND label = $2',
      [newVehicleId, label]
    );
    if (!rowCount) missing.push(label);
  }
  if (missing.length) {
    return res.status(400).json({
      error: `Vehiculul nou nu are locurile: ${missing.join(', ')}.`
    });
  }

  // 4. Începe tranzacție: migrăm rezervările și schimbăm vehicle_id în trips
  try {
    await pool.query('BEGIN');

    // 4.a. actualizează seat_id pentru fiecare rezervare activă
    for (let { id, label } of reservations) {
      const { rows: seatRows } = await pool.query(
        'SELECT id FROM seats WHERE vehicle_id = $1 AND label = $2',
        [newVehicleId, label]
      );
      await pool.query(
        'UPDATE reservations SET seat_id = $1 WHERE id = $2',
        [seatRows[0].id, id]
      );
    }

    // 4.b. schimbă vehicle_id în trips
    await pool.query(
      'UPDATE trips SET vehicle_id = $1 WHERE id = $2',
      [newVehicleId, tripId]
    );

    // 4.c. sincronizează şi trip_vehicles → rândul marcat is_primary = true
await pool.query(
  `UPDATE trip_vehicles
     SET vehicle_id = $1
   WHERE trip_id = $2
     AND is_primary = true`,
  [newVehicleId, tripId]
);


    await pool.query('COMMIT');
    return res.json({ success: true });
  } catch (err) {
    await pool.query('ROLLBACK');
    console.error(err);
    return res.status(500).json({ error: 'Eroare la migrarea rezervărilor.' });
  }
});


// routes/trips.js  ──────────────────────────────────────────────────────────
router.post('/autogenerate', async (req, res) => {
  const { date } = req.query;                 // ?date=YYYY-MM-DD opțional
  const startDate = date ? new Date(date) : new Date();

  try {
    let insertedTrips = 0;
    let updatedTrips  = 0;
    let insertedTV    = 0;                    // trip_vehicles noi

    // ───────────────────────── iterate 7 zile
    for (let d = 0; d < 7; d++) {
      const curr       = new Date(startDate);
      curr.setDate(startDate.getDate() + d);
      const dateStr    = curr.toISOString().slice(0, 10);

      // 1️⃣  toate programele + flag should_disable
      const { rows: schedules } = await db.query(`
        SELECT
          rs.id           AS schedule_id,
          rs.route_id,
          rs.departure,
          rs.operator_id,
          EXISTS(
            SELECT 1
              FROM schedule_exceptions se
             WHERE se.schedule_id = rs.id
               AND se.disable_run  = true
               AND (
                    se.exception_date IS NULL
                 OR se.exception_date = $1
                 OR se.weekday        = EXTRACT(DOW FROM $1)::smallint
               )
          ) AS should_disable
        FROM route_schedules rs
      `, [dateStr]);

      // 2️⃣  pentru fiecare program – creează / sincronizează trip + vehicul
      for (const s of schedules) {
        // vehiculul implicit al operatorului
        const { rows: veh } = await db.query(
          'SELECT id FROM vehicles WHERE operator_id = $1 LIMIT 1',
          [s.operator_id]
        );
        if (!veh.length) continue;
        const defaultVehicleId = veh[0].id;

        // 2.a  upsert în trips  (cheie: route_id + date + time + vehicle_id)
        const tripRes = await db.query(`
          INSERT INTO trips
                 (route_schedule_id, route_id, vehicle_id, date, time, disabled)
          VALUES ($1,$2,$3,$4,$5,$6)
          ON CONFLICT (route_id, date, "time", vehicle_id)
          DO UPDATE SET disabled = EXCLUDED.disabled
          RETURNING id, xmax = 0 AS inserted             -- xmax=0 => tocmai s-a inserat
        `, [s.schedule_id, s.route_id, defaultVehicleId,
            dateStr,        s.departure,  s.should_disable]);

        if (tripRes.rows[0].inserted) insertedTrips++; else updatedTrips++;

        const tripId = tripRes.rows[0].id;

        // 2.b  upsert în trip_vehicles (cheie: trip_id + vehicle_id)
        const tvRes = await db.query(`
          INSERT INTO trip_vehicles (trip_id, vehicle_id, is_primary)
          VALUES ($1, $2, true)
          ON CONFLICT (trip_id, vehicle_id) DO NOTHING
          RETURNING 1
        `, [tripId, defaultVehicleId]);

        if (tvRes.rowCount) insertedTV++;
      }
    }

    res.json({
      status:   'ok',
      inserted: { trips: insertedTrips, trip_vehicles: insertedTV },
      updated:  { trips: updatedTrips }
    });
  } catch (err) {
    console.error('POST /api/trips/autogenerate error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});
;
;


// POST /api/trips/exceptions/cleanup face din true-false pentru toate trips la care cursele in schedule_exceptions disable_run e true
router.post('/exceptions/cleanup', async (req, res) => {
  const { schedule_id, exception_date } = req.body;
  try {
    await db.query(`
      UPDATE trips t
         SET disabled = true
        FROM schedule_exceptions se
       WHERE se.schedule_id     = t.route_schedule_id
         AND se.disable_run     = true
         AND se.exception_date   = $1
         AND (
              se.exception_date = t.date
           OR se.weekday        = EXTRACT(DOW FROM t.date)::smallint
         )
    `, [exception_date]);
    res.json({ status: 'ok' });
  } catch (err) {
    console.error('Cleanup failed:', err);
    res.status(500).json({ error: 'cleanup failed' });
  }
});




// POST /api/trips/exceptions/reactivate in tabelul schedule_exceptions setează disable_run și disable_online la false pentru o zi și schedule_id date
// POST /api/trips/exceptions/update
// -----------------------------
// POST  /api/trips/exceptions/update
// -----------------------------
router.post('/exceptions/update', async (req, res) => {
  const {
    schedule_id,
    exception_date = null,          // NULL  ⇒ permanent
    weekday = null,          // 0–6   ⇒ recurent pe zi
    disable_run,
    disable_online
  } = req.body;

  const createdBy = req.user?.id || 12;        // ajustează după cum vrei

  // 1️⃣  Validare
  if (!schedule_id) {
    return res.status(400).json({ error: 'schedule_id lipsă' });
  }
  if (typeof disable_run !== 'boolean' && typeof disable_online !== 'boolean') {
    return res.status(400).json({ error: 'Trebuie cel puţin un flag' });
  }

  try {
    await db.query('BEGIN');

    // 2️⃣  Propagare „în lanţ”
    let runFlag = disable_run;
    let onlineFlag = disable_online;
    if (typeof disable_run === 'boolean') {
      if (disable_run) onlineFlag = true;                     // oprire totală ⇒ opreşte şi online
      else if (typeof disable_online !== 'boolean') onlineFlag = false; // reactivare ⇒ porneşte şi online
    }

    // ȘI ÎN LOCUL LOR INSEREAZĂ:
    // 3️⃣ Manual upsert pentru a gestiona NULL-uri
    const findRes = await db.query(
      `SELECT id FROM schedule_exceptions
         WHERE schedule_id     = $1
           AND exception_date IS NOT DISTINCT FROM $2
           AND weekday        IS NOT DISTINCT FROM $3`,
      [schedule_id, exception_date, weekday]
    );
    let ruleId;
    if (findRes.rowCount) {
      // există → UPDATE
      ruleId = findRes.rows[0].id;
      await db.query(
        `UPDATE schedule_exceptions
            SET disable_run    = $2,
                disable_online = $3
          WHERE id = $1`,
        [ruleId, runFlag ?? false, onlineFlag ?? false]
      );
    } else {
      // nu există → INSERT
      const insRes = await db.query(
        `INSERT INTO schedule_exceptions
           (schedule_id, exception_date, weekday,
            disable_run, disable_online, created_by_employee_id)
         VALUES ($1,$2,$3,$4,$5,$6)
         RETURNING id`,
        [schedule_id, exception_date, weekday,
          runFlag ?? false, onlineFlag ?? false, createdBy]
      );
      ruleId = insRes.rows[0].id;
    }
    // citim valorile actualizate
    const upFlagRes = await db.query(
      `SELECT disable_run, disable_online
         FROM schedule_exceptions
        WHERE id = $1`,
      [ruleId]
    );
    const { disable_run: dbRun, disable_online: dbOnline } = upFlagRes.rows[0];
    // 4️⃣ Sincronizare trips.disabled
    let dateClause, params = [dbRun, schedule_id];

    if (exception_date) {
      dateClause = 'date = $3';                // $3 = exception_date
      params.push(exception_date);
    } else if (weekday !== null) {
      dateClause = 'date >= CURRENT_DATE AND EXTRACT(DOW FROM date)::int = $3';
      params.push(weekday);                    // $3 = weekday
    } else {
      dateClause = 'date >= CURRENT_DATE';     // permanent
    }

    const tripsUpd = await db.query(
      `UPDATE trips
          SET disabled = $1
        WHERE route_schedule_id = $2
          AND ${dateClause}`,
      params
    );

    await db.query('COMMIT');

    // 5️⃣  Răspuns
    res.json({
      status: 'ok',
      disable_run: dbRun,
      disable_online: dbOnline,
      tripsUpdated: tripsUpd.rowCount
    });
  } catch (err) {
    await db.query('ROLLBACK');
    console.error('Update exception failed:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});
;
;


// -----------------------------------------------------------
// GET  /api/admin/disabled-schedules
// Listează TOATE regulile active (de azi încolo sau permanente)
// -----------------------------------------------------------
router.get('/admin/disabled-schedules', async (_req, res) => {
  try {
    const { rows } = await db.query(`
      SELECT
        se.id,
        rs.id                   AS schedule_id,
        r.name                  AS route_name,
        to_char(rs.departure, 'HH24:MI') AS hour,
        /* tipul de regulă: permanent / date / weekday */
        CASE
          WHEN se.exception_date IS NULL AND se.weekday IS NULL THEN 'permanent'
          WHEN se.exception_date IS NOT NULL                      THEN 'date'
          ELSE 'weekday'
        END                     AS rule_type,
        /* dată exactă sau zi-din-săptămână */
        to_char(se.exception_date, 'YYYY-MM-DD') AS exception_date,
        se.weekday,
        se.disable_run,
        se.disable_online,
        /* câte curse au deja disabled = true */
        (
          SELECT COUNT(*)
            FROM trips t
           WHERE t.route_schedule_id = rs.id
             AND (
                   /* permanent ⇒ toate zilele ≥ azi */
                   (se.exception_date IS NULL AND se.weekday IS NULL AND t.date >= CURRENT_DATE)
                   /* weekday ⇒ toate zilele ≥ azi cu acelaşi DOW */
                OR (se.exception_date IS NULL AND se.weekday IS NOT NULL
                    AND t.date >= CURRENT_DATE
                    AND EXTRACT(DOW FROM t.date)::int = se.weekday)
                   /* dată fixă ⇒ numai acea zi */
                OR (se.exception_date IS NOT NULL AND t.date = se.exception_date)
                 )
             AND t.disabled = true
        )                       AS trips_affected
      FROM schedule_exceptions se
      JOIN route_schedules  rs ON rs.id = se.schedule_id
      JOIN routes           r  ON r.id  = rs.route_id
      WHERE
            /* regulă valabilă de azi încolo */
            (se.exception_date IS NULL OR se.exception_date >= CURRENT_DATE)
        AND (se.disable_run OR se.disable_online)       -- mă interesează doar cele active
      ORDER BY route_name, hour;
    `);

    res.json(rows);   // front-end primeşte direct un array de obiecte
  } catch (err) {
    console.error('Fetch disabled schedules failed:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});




// -----------------------------------------------------------
// DELETE  /api/trips/admin/disabled-schedules/:id
// Șterge regula și re-activează cursele afectate
// -----------------------------------------------------------
router.delete('/admin/disabled-schedules/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await db.query('BEGIN');

    // 1️⃣ Citește regula ca să știm schedule_id + interval
    const ruleRes = await db.query(
      `SELECT schedule_id, exception_date, weekday
         FROM schedule_exceptions
        WHERE id = $1`,
      [id]
    );
    if (ruleRes.rowCount === 0) {
      await db.query('ROLLBACK');
      return res.status(404).json({ error: 'Regula nu exista' });
    }
    const { schedule_id, exception_date, weekday } = ruleRes.rows[0];

    // 2️⃣ Șterge regula
    await db.query(
      `DELETE FROM schedule_exceptions WHERE id = $1`,
      [id]
    );

    // 3️⃣ Reactivare trips.disabled = false pe intervalul acela
    let dateClause;
    const params = [false, schedule_id]; // $1 = disabled, $2 = schedule_id

    if (exception_date) {
      // dată fixă
      dateClause = 'date = $3';
      params.push(exception_date);
    } else if (weekday !== null) {
      // zi din săptămână
      dateClause = 'date >= CURRENT_DATE AND EXTRACT(DOW FROM date)::int = $3';
      params.push(weekday);
    } else {
      // permanent
      dateClause = 'date >= CURRENT_DATE';
    }

    const tripsUpd = await db.query(
      `UPDATE trips
          SET disabled = $1
        WHERE route_schedule_id = $2
          AND ${dateClause}`,
      params
    );

    await db.query('COMMIT');

    // 4️⃣ Răspuns
    res.json({
      status: 'ok',
      tripsUpdated: tripsUpd.rowCount
    });
  } catch (err) {
    await db.query('ROLLBACK');
    console.error('Delete disabled schedule failed:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});




// Exportă routerul pentru a fi folosit în server.js
module.exports = router;
