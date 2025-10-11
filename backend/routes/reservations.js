// Importă framework-ul Express pentru a crea rute HTTP
const express = require('express');
// Importă conexiunea la baza de date (modulul db)
const db = require('../db');
// Creează un router Express pentru a defini rutele API
// Creează un router Express pentru a defini rutele disponibile în această secțiune
const router = express.Router();


// helper: cache-uim array-ul de stații (în sequence) pentru o rută
const stopCache = new Map();
async function getStops(routeId) {
  if (stopCache.has(routeId)) return stopCache.get(routeId);

  const { rows } = await db.query(`
    SELECT rs.station_id, s.name, rs.sequence
    FROM route_stations rs
    JOIN stations s ON s.id = rs.station_id
    WHERE rs.route_id = $1
    ORDER BY rs.sequence
  `, [routeId]);

  const ordered = rows.map((r, index) => ({
    id: r.station_id,
    name: r.name,
    index,
  }));

  const indexById = new Map();

  ordered.forEach(stop => {
    const idKey = String(stop.id);
    indexById.set(idKey, stop.index);
  });

  const cacheEntry = { ordered, indexById };
  stopCache.set(routeId, cacheEntry);
  return cacheEntry;
}

const parseStationId = value => {
  if (value === undefined || value === null || value === '') return null;
  const num = Number(value);
  return Number.isNaN(num) ? null : num;
};

const ensureStationId = (stopsInfo, value) => {
  const parsed = parseStationId(value);
  if (parsed === null) return null;
  return stopsInfo.indexById.has(String(parsed)) ? parsed : null;
};

const getStationIndex = (stopsInfo, stationId) => {
  if (stationId === null || stationId === undefined) return -1;
  const idx = stopsInfo.indexById.get(String(stationId));
  return idx === undefined ? -1 : idx;
};



function isPassengerValid(passenger) {
  const { name, phone } = passenger;

  const nameValid = !name || /^[a-zA-Z0-9ăîâșțĂÎÂȘȚ \-]+$/.test(name.trim());
  const cleanedPhone = phone?.replace(/\s+/g, '') || '';
  const phoneValid = !phone || /^(\+)?\d{10,}$/.test(cleanedPhone);
  const hasAtLeastOne = (name && name.trim()) || (phone && phone.trim());

  return hasAtLeastOne && nameValid && phoneValid;
}





// Creează rezervări
// Definește ruta POST (ex: creare înregistrări)
// Definește o rută POST - folosită pentru a trimite date către server pentru salvare
router.post('/', async (req, res) => {
  console.log('Primit payload:', req.body);

  const {
    date,                // ex: "2025-10-09"
    time,                // ex: "06:00"
    route_id,            // <-- OBLIGATORIU ACUM (NU mai folosim route_name)
    vehicle_id,          // id mașină
    price_list_id,       // id listă de preț
    booking_channel = 'online',
    passengers,          // array
  } = req.body;

  // Validări de bază pe câmpuri obligatorii
  if (!date || !time || !route_id || !vehicle_id || !Array.isArray(passengers) || passengers.length === 0) {
    return res.status(400).json({ error: 'date/time/route_id/vehicle_id/passengers lipsă sau invalide' });
  }

  // ✅ VALIDARE PASAGERI (nume/telefon opționale, dar format corect dacă există)
  for (const p of passengers) {
    if (!isPassengerValid(p)) {
      return res.status(400).json({ error: 'Datele pasagerului nu sunt valide (nume sau telefon).' });
    }
  }

  try {
    // 1) Stațiile rutei (strict pe ID)
    const stopsInfo = await getStops(route_id);
    if (!stopsInfo.ordered.length) {
      return res.status(400).json({ error: 'Ruta nu are stații definite' });
    }

    // 2) Găsim sau creăm TRIP pe baza ID-urilor (fără route_name)
    let tripRes = await db.query(
      'SELECT id FROM trips WHERE route_id = $1 AND vehicle_id = $2 AND date = $3 AND time = $4',
      [route_id, vehicle_id, date, time]
    );
    let trip_id;
    if (tripRes.rows.length > 0) {
      trip_id = tripRes.rows[0].id;
    } else {
      const insertTrip = await db.query(
        'INSERT INTO trips (route_id, vehicle_id, date, time) VALUES ($1, $2, $3, $4) RETURNING id',
        [route_id, vehicle_id, date, time]
      );
      trip_id = insertTrip.rows[0].id;
    }

    // 3) Parcurgem pasagerii (doar ID-uri pentru stații)
    for (const p of passengers) {
      const boardStationId = ensureStationId(stopsInfo, p.board_station_id);
      const exitStationId = ensureStationId(stopsInfo, p.exit_station_id);

      if (boardStationId === null || exitStationId === null) {
        return res.status(400).json({ error: 'Stație de urcare/coborâre invalidă pentru pasager.' });
      }

      // 3.1) Rezolvăm person_id
      let person_id;
const name = (p.name || '').trim();
const phone = p.phone ? p.phone.replace(/\D/g, '') : null;
      // preferăm DOAR ID dacă vine din payload
      if (p.person_id && Number.isInteger(Number(p.person_id))) {
        person_id = Number(p.person_id);
      }

      if (p.reservation_id) {
        const row = await db.query('SELECT person_id FROM reservations WHERE id = $1', [p.reservation_id]);
        person_id = row.rows[0]?.person_id;
      }
      if (!person_id) {
        if (phone) {
          const resP = await db.query('SELECT id, name FROM people WHERE phone = $1', [phone]);
          if (resP.rowCount) {
            person_id = resP.rows[0].id;
            if (name && name !== resP.rows[0].name) {
              await db.query('UPDATE people SET name = $1 WHERE id = $2', [name, person_id]);
            }
          } else {
            const ins = await db.query('INSERT INTO people (name, phone) VALUES ($1, $2) RETURNING id', [name, phone]);
            person_id = ins.rows[0].id;
          }
        } else {
          const resP2 = await db.query('SELECT id FROM people WHERE name = $1 AND phone IS NULL', [name]);
          if (resP2.rowCount) {
            person_id = resP2.rows[0].id;
          } else {
            const ins = await db.query('INSERT INTO people (name, phone) VALUES ($1, NULL) RETURNING id', [name]);
            person_id = ins.rows[0].id;
          }
        }
      }

      // 3.2) Creare/Actualizare rezervare (NUMAI cu board_station_id/exit_station_id)
      if (p.reservation_id) {
        await db.query(
          `UPDATE reservations
             SET person_id        = $1,
                 seat_id          = $2,
                 board_station_id = $3,
                 exit_station_id  = $4,
                 observations     = $5,
                 created_by       = $7
           WHERE id = $6`,
          [
            person_id,
            p.seat_id,
            boardStationId,
            exitStationId,
            p.observations || null,
            p.reservation_id,
            1
          ]
        );
      } else {
        const insertRes = await db.query(
          `INSERT INTO reservations
  (trip_id, seat_id, person_id, board_station_id, exit_station_id, observations, created_by)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id`,
          [
            trip_id,
            p.seat_id,
            person_id,
            boardStationId,
            exitStationId,
            p.observations || null,
            12
          ]
        );
        const newResId = insertRes.rows[0].id;

        // Discount (opțional, dar pe ID-uri)
        let discountAmount = 0;
        if (p.discount_type_id) {
          const { rows } = await db.query(
            `SELECT id, code, label, value_off, type
               FROM discount_types
              WHERE id = $1`,
            [p.discount_type_id]
          );
          if (!rows.length) throw new Error('Tip de discount inexistent');
          const disc = rows[0];
          discountAmount = disc.type === 'percent'
            ? +(p.price * disc.value_off / 100).toFixed(2)
            : +disc.value_off;
          discountAmount = Math.min(discountAmount, p.price);
          await db.query(
            `INSERT INTO reservation_discounts
               (reservation_id, discount_type_id, discount_amount, discount_snapshot)
             VALUES ($1, $2, $3, $4)`,
            [newResId, disc.id, discountAmount,
              typeof disc.value_off === 'number' ? disc.value_off : parseFloat(disc.value_off)
            ]
          );
        }

        // Pricing (strict pe ID-uri)
        const netPrice = (p.price ?? 0) - discountAmount;
        const listId = p.price_list_id || price_list_id;
        if (!listId) throw new Error('price_list_id lipsă în payload');
        await db.query(
          `INSERT INTO reservation_pricing
             (reservation_id, price_value, price_list_id, pricing_category_id, booking_channel, employee_id)
           VALUES ($1, $2, $3, $4, $5, 12)`,
          [newResId, netPrice, listId, p.category_id, booking_channel]
        );

        // Plată (opțional)
        if (p.payment_method && p.payment_method !== 'none') {
          await db.query(
            `INSERT INTO payments
               (reservation_id, amount, status, payment_method, transaction_id, timestamp)
             VALUES ($1, $2, 'paid', $3, $4, NOW())`,
            [newResId, netPrice, p.payment_method, p.transaction_id || null]
          );
        }
      }
    }

    res.status(201).json({ message: 'Rezervare salvată' });
  } catch (err) {
    console.error('Eroare la salvarea rezervării:', err);
    res.status(500).json({ error: 'Eroare internă la salvare' });
  }
});
;

// Definește ruta GET (ex: listare date)
// Definește o rută GET - folosită pentru a obține date din server
router.get('/backup', async (req, res) => {
  // Folosește blocul try pentru a prinde eventualele erori
  // Începe un bloc try-catch pentru tratarea erorilor
  // Combină tabele SQL pentru a obține date corelate din mai multe surse
  // Combină tabele SQL pentru a obține date corelate din mai multe surse
  try {
    const { trip_id } = req.query;

    const query = `
      SELECT b.id AS backup_id, b.reservation_id, b.seat_id, s.label, b.trip_id, b.backup_time,
             p.name AS passenger_name, p.phone
      FROM reservations_backup b

      LEFT JOIN people p ON b.person_id = p.id

      LEFT JOIN seats s ON b.seat_id = s.id
      ${trip_id ? 'WHERE b.trip_id = $1' : ''}
      ORDER BY b.backup_time DESC
    `;

    // Execută o interogare SQL folosind conexiunea la baza de date
    // Execută o interogare în PostgreSQL folosind modulul 'db'
    const result = await db.query(query, trip_id ? [trip_id] : []);
    // Trimite răspunsul înapoi către client sub formă de JSON
    res.json(result.rows);
    // Prinde orice eroare apărută în blocul try și o tratează corespunzător
  } catch (err) {
    // Afișează o eroare în consola backend-ului pentru depanare
    console.error('Eroare la interogarea backupurilor:', err);
    // Răspunde clientului cu un cod de stare HTTP și un mesaj JSON
    res.status(500).json({ error: 'Eroare la interogarea backupurilor' });
  }
});

// Exportă routerul pentru a fi folosit în server.js


// 🔥 Șterge o rezervare activă după parametrii seat_id, trip_id etc.
router.post('/delete', async (req, res) => {
  const { seat_id, trip_id } = req.body;
  const boardStationId = parseStationId(req.body.board_station_id);
  const exitStationId = parseStationId(req.body.exit_station_id);

  if (!seat_id || !trip_id || boardStationId === null || exitStationId === null) {
    return res.status(400).json({ error: 'Parametri lipsă' });
  }

  try {
    const result = await db.query(
      `DELETE FROM reservations
         WHERE seat_id = $1 AND trip_id = $2 AND board_station_id = $3 AND exit_station_id = $4`,
      [seat_id, trip_id, boardStationId, exitStationId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Rezervarea nu a fost găsită' });
    }

    res.json({ success: true });
  } catch (err) {
    console.error('Eroare la ștergere rezervare:', err);
    res.status(500).json({ error: 'Eroare la ștergere' });
  }
});



// 🔥 Șterge o rezervare după id folosit in stergerea direct din modalul cu conflicte
// 🔥 Șterge o rezervare după ID
router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await db.query(
      'DELETE FROM reservations WHERE id = $1',
      [id]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Rezervarea nu a fost găsită' });
    }
    res.json({ success: true });
  } catch (err) {
    console.error('Eroare la DELETE /reservations/:id', err);
    res.status(500).json({ error: 'Eroare internă la ștergere' });
  }
});
;





// Mută o rezervare pe altă cursă/trip/zi/loc (cu verificare suprapunere segment!)
router.post('/moveToOtherTrip', async (req, res) => {
  console.log('[moveToOtherTrip] payload primit:', req.body);
  const {
    old_reservation_id,
    new_trip_id,
    new_seat_id,
    board_station_id,
    exit_station_id,
    phone,
    name,
    booking_channel = 'online',
    observations    // opțional
  } = req.body;

  const parsedBoardId = parseStationId(board_station_id);
  const parsedExitId = parseStationId(exit_station_id);

  if (!old_reservation_id || !new_trip_id || !new_seat_id || parsedBoardId === null || parsedExitId === null) {
    return res.status(400).json({ error: 'Missing required data' });
  }

  try {
    const tripInfoRes = await db.query('SELECT route_id FROM trips WHERE id = $1', [new_trip_id]);
    if (!tripInfoRes.rowCount) {
      return res.status(400).json({ error: 'Cursa selectată nu există' });
    }

    const stopsInfo = await getStops(tripInfoRes.rows[0].route_id);
    if (!stopsInfo.ordered.length) {
      return res.status(400).json({ error: 'Ruta nu are stații definite' });
    }

    const boardStationId = ensureStationId(stopsInfo, parsedBoardId);
    const exitStationId = ensureStationId(stopsInfo, parsedExitId);

    if (boardStationId === null || exitStationId === null) {
      return res.status(400).json({ error: 'Stații invalide pentru mutare' });
    }

    const newBoardIndex = getStationIndex(stopsInfo, boardStationId);
    const newExitIndex = getStationIndex(stopsInfo, exitStationId);

    if (newBoardIndex === -1 || newExitIndex === -1 || newBoardIndex >= newExitIndex) {
      return res.status(400).json({ error: 'Segment invalid pentru mutare' });
    }

    // 1. Backup vechea rezervare
    await db.query(`
      INSERT INTO reservations_backup (reservation_id, trip_id, seat_id, label, person_id)
      SELECT id, trip_id, seat_id, '', person_id
      FROM reservations
      WHERE id = $1
    `, [old_reservation_id]);
    console.log('[moveToOtherTrip] Rezervare veche backup:', old_reservation_id);

    // 2. Dezactivează vechea rezervare
    const updateRes = await db.query(`
  UPDATE reservations
  SET status = 'canceled'
  WHERE id = $1
`, [old_reservation_id]);
    console.log('[moveToOtherTrip] Rezervare veche dezactivată:', old_reservation_id, '| rowCount:', updateRes.rowCount);


    // 3. Găsește/creează persoana
    let person_id;
    if (phone) {
      const personRes = await db.query(
        `SELECT id FROM people WHERE phone = $1`,
        [phone]
      );
      if (personRes.rows.length > 0) {
        person_id = personRes.rows[0].id;
      } else {
        // Creează persoana dacă nu există
        const insertRes = await db.query(
          `INSERT INTO people (name, phone) VALUES ($1, $2) RETURNING id`,
          [name || '', phone]
        );
        person_id = insertRes.rows[0].id;
      }
    } else {
      // Ia person_id din vechea rezervare (fallback)
      const oldRes = await db.query(
        `SELECT person_id FROM reservations WHERE id = $1`,
        [old_reservation_id]
      );
      person_id = oldRes.rows[0]?.person_id;
    }

    // 4. Verifică dacă există coliziune pe segment pe noua cursă/loc!
    const overlapRes = await db.query(
      `SELECT board_station_id, exit_station_id
         FROM reservations
        WHERE trip_id = $1 AND seat_id = $2 AND status = 'active'`,
      [new_trip_id, new_seat_id]
    );

    const hasOverlap = overlapRes.rows.some(r => {
      const rBoard = getStationIndex(stopsInfo, r.board_station_id);
      const rExit = getStationIndex(stopsInfo, r.exit_station_id);
      return Math.max(newBoardIndex, rBoard) < Math.min(newExitIndex, rExit);
    });

    if (hasOverlap) {
      console.log('[moveToOtherTrip] Coliziune segment la mutare!');
      return res.status(400).json({ error: 'Loc deja ocupat pe segmentul respectiv!' });
    }

    // 5. Creează rezervarea nouă
    const insertRes = await db.query(
      `INSERT INTO reservations
  (trip_id, seat_id, person_id, board_station_id, exit_station_id, observations, status, created_by)
VALUES ($1, $2, $3, NULL, NULL, $4, $5, $6, 'active', $7)
    RETURNING id`,
      [
        new_trip_id,
        new_seat_id,
        person_id,
        boardStationId,
        exitStationId,
        observations || null,
        1                           // hard-codat pentru creator
      ]
    );


    const newReservationId = insertRes.rows[0].id;

    // ─────────── Copiem detaliile tarifare din rezervarea veche ───────────
    await db.query(
      `INSERT INTO reservation_pricing (reservation_id, price_value, price_list_id, pricing_category_id, booking_channel, employee_id)
       SELECT $1, price_value, price_list_id, pricing_category_id, $2, employee_id
       FROM reservation_pricing
       WHERE reservation_id = $3`,
      [newReservationId, booking_channel, old_reservation_id]
    );


    console.log('[moveToOtherTrip] Rezervare NOUĂ inserată:', insertRes.rows[0].id);

    res.json({ success: true, new_reservation_id: insertRes.rows[0].id });
  } catch (err) {
    console.error('Eroare la mutare pe alt trip:', err);
    res.status(500).json({ error: 'Eroare la mutare pe altă cursă' });
  }
});




// ─── Verifică dacă există rezervare same-day, same-direction, altă oră ───
// ─── Verifică rezervări same-day, same-direction pentru un telefon ───
// backend/routes/reservations.js
router.get('/conflict', async (req, res) => {
  const { person_id: qPersonId, date, time } = req.query;
  const boardStationId = parseStationId(req.query.board_station_id);
  const exitStationId = parseStationId(req.query.exit_station_id);

  if (!date || !time || boardStationId === null || exitStationId === null) {
    return res.status(400).json({ error: 'Lipsește date/stații/time' });
  }

  try {
    // 1) person_id este obligatoriu (DOAR ID)
    const pid = Number(qPersonId);
    if (!Number.isInteger(pid) || pid <= 0) {
      return res.status(400).json({ error: 'person_id lipsă sau invalid' });
    }
    const person_id = pid;


    // 2) sql-ul care aduce toate rezervările conflictuale din aceeași zi
    // ——— bloc SQL NOU ———
    const sql = `
  SELECT
    r.id               AS reservation_id,
    ro.id              AS route_id,
    ro.name            AS route_name,
    t.time             AS time,
    s.label            AS seat_label,
    r.board_station_id AS board_station_id,
    r.exit_station_id  AS exit_station_id
  FROM reservations r
  JOIN trips   t  ON t.id  = r.trip_id
  JOIN routes  ro ON ro.id = t.route_id
  JOIN seats   s  ON s.id  = r.seat_id
  WHERE r.person_id = $1
    AND t.date      = $2
    AND r.status    = 'active'
    AND t.time     <> $3         -- altă oră decât cea cerută
`;


    // 3) execută interogarea
    const { rows } = await db.query(sql, [
      person_id,   // $1
      date,        // $2
      time         // $3   (ora pe care o excluzi)
    ]);



    // 4) verificăm suprapunerea segmentelor direct în JS
    const conflictInfos = [];

    for (const r of rows) {
      const stopsInfo = await getStops(r.route_id);

      const iOldBoard = getStationIndex(stopsInfo, r.board_station_id);
      const iOldExit = getStationIndex(stopsInfo, r.exit_station_id);
      const iNewBoard = getStationIndex(stopsInfo, boardStationId);
      const iNewExit = getStationIndex(stopsInfo, exitStationId);

      // ignorăm dacă vreo stație lipsește pe rută
      if ([iOldBoard, iOldExit, iNewBoard, iNewExit].includes(-1)) continue;

      const overlap =
        iOldBoard < iOldExit &&           // segment vechi valid
        iNewBoard < iNewExit &&           // segment nou valid
        Math.max(iOldBoard, iNewBoard) <= Math.min(iOldExit, iNewExit);

      if (overlap) conflictInfos.push(r);
    }

    res.json({
      conflict: conflictInfos.length > 0,
      infos: conflictInfos.map(r => ({
        id: r.reservation_id,
        route: r.route_name,
        time: r.time,
        seatLabel: r.seat_label,
        board_station_id: r.board_station_id,
        exit_station_id: r.exit_station_id
      }))
    });


  } catch (err) {
    console.error('Eroare la /reservations/conflict:', err);
    res.status(500).json({ error: 'server error' });
  }
});

module.exports = router;

