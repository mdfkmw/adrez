// backend/routes/reservations.js (MariaDB 10.6)
const express = require('express');
const db = require('../db');
const router = express.Router();



 // ── Config fiscală din .env (asemenea routes/cash.js)
 const FISCAL_URL = process.env.FISCAL_PRINTER_URL || '';
 const FISCAL_ON  = String(process.env.FISCAL_ENABLED || 'true').toLowerCase() === 'true';
 const FISCAL_TO  = Number(process.env.FISCAL_TIMEOUT_MS || 6000);






/* ---------------------- helpers: stații/valideri ---------------------- */

const stopCache = new Map();

async function getStops(routeId) {
  if (stopCache.has(routeId)) return stopCache.get(routeId);

  const result = await db.query(
    `
    SELECT rs.station_id, s.name, rs.sequence
    FROM route_stations rs
    JOIN stations s ON s.id = rs.station_id
    WHERE rs.route_id = ?
    ORDER BY rs.sequence
    `,
    [routeId]
  );

  const ordered = result.rows.map((r, index) => ({
    id: r.station_id,
    name: r.name,
    index,
  }));

  const indexById = new Map();
  ordered.forEach((stop) => {
    indexById.set(String(stop.id), stop.index);
  });

  const cacheEntry = { ordered, indexById };
  stopCache.set(routeId, cacheEntry);
  return cacheEntry;
}

const parseStationId = (value) => {
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

/* ----------------------------- CREATE ----------------------------- */
/**
 * POST /api/reservations
 * Body: { date, time, route_id, vehicle_id, price_list_id, booking_channel, passengers: [...] }
 */
router.post('/', async (req, res) => {
  console.log('Primit payload:', req.body);

  const {
    date,
    time,
    route_id,
    vehicle_id,
    price_list_id,
    booking_channel = 'online',
    pay_cash_now = false,       // <— nou: dacă e true și passenger.payment_method==='cash', vom printa imediat
    cash_description,           // <— opțional: descriere pe bon
   passengers,
  } = req.body;

  if (
    !date ||
    !time ||
    !route_id ||
    !vehicle_id ||
    !Array.isArray(passengers) ||
    passengers.length === 0
  ) {
    return res
      .status(400)
      .json({ error: 'date/time/route_id/vehicle_id/passengers lipsă sau invalide' });
  }

  // ID-urile rezervărilor NOI create în acest request (pt. tipărire fiscala imediată)
  const createdReservationIds = [];

  for (const p of passengers) {
    if (!isPassengerValid(p)) {
      return res.status(400).json({ error: 'Datele pasagerului nu sunt valide (nume sau telefon).' });
    }
  }

  try {
    // 1) stațiile rutei
    const stopsInfo = await getStops(route_id);
    if (!stopsInfo.ordered.length) {
      return res.status(400).json({ error: 'Ruta nu are stații definite' });
    }

    // 2) trip existent sau îl creăm
    let trip_id;
    const tripRes = await db.query(
      'SELECT id FROM trips WHERE route_id=? AND vehicle_id=? AND date=? AND time=?',
      [route_id, vehicle_id, date, time]
    );
    if (tripRes.rows.length > 0) {
      trip_id = tripRes.rows[0].id;
    } else {
      const ins = await db.query(
        'INSERT INTO trips (route_id, vehicle_id, date, time) VALUES (?, ?, ?, ?)',
        [route_id, vehicle_id, date, time]
      );
      trip_id = ins.insertId;
    }

    // 3) pasageri
    for (const p of passengers) {
      const boardStationId = ensureStationId(stopsInfo, p.board_station_id);
      const exitStationId = ensureStationId(stopsInfo, p.exit_station_id);
      if (boardStationId === null || exitStationId === null) {
        return res.status(400).json({ error: 'Stație de urcare/coborâre invalidă pentru pasager.' });
      }

      // 3.1) person_id
      let person_id;
      const name = (p.name || '').trim();
      const phone = p.phone ? p.phone.replace(/\D/g, '') : null;

      if (p.person_id && Number.isInteger(Number(p.person_id))) {
        person_id = Number(p.person_id);
      }

      if (!person_id && p.reservation_id) {
        const row = await db.query('SELECT person_id FROM reservations WHERE id = ?', [p.reservation_id]);
        person_id = row.rows[0]?.person_id;
      }

      if (!person_id) {
        if (phone) {
          const resP = await db.query('SELECT id, name FROM people WHERE phone = ?', [phone]);
          if (resP.rowCount) {
            person_id = resP.rows[0].id;
            if (name && name !== resP.rows[0].name) {
              await db.query('UPDATE people SET name=? WHERE id=?', [name, person_id]);
            }
          } else {
            const ins = await db.query('INSERT INTO people (name, phone) VALUES (?, ?)', [name, phone]);
            person_id = ins.insertId;
          }
        } else {
          const resP2 = await db.query('SELECT id FROM people WHERE name = ? AND phone IS NULL', [name]);
          if (resP2.rowCount) {
            person_id = resP2.rows[0].id;
          } else {
            const ins = await db.query('INSERT INTO people (name, phone) VALUES (?, NULL)', [name]);
            person_id = ins.insertId;
          }
        }
      }

      // 3.2) rezervare: update sau insert nou
      if (p.reservation_id) {
        await db.query(
          `
          UPDATE reservations
             SET person_id        = ?,
                 seat_id          = ?,
                 board_station_id = ?,
                 exit_station_id  = ?,
                 observations     = ?,
                 created_by       = ?
           WHERE id = ?
          `,
          [person_id, p.seat_id, boardStationId, exitStationId, p.observations || null, 1, p.reservation_id]
        );
      } else {
        const insRes = await db.query(
          `
          INSERT INTO reservations
            (trip_id, seat_id, person_id, board_station_id, exit_station_id, observations, status, created_by)
          VALUES (?, ?, ?, ?, ?, ?, 'active', ?)
          `,
          [trip_id, p.seat_id, person_id, boardStationId, exitStationId, p.observations || null, 12]
        );
        const newResId = insRes.insertId;
        createdReservationIds.push(newResId);

        // Discount (opțional)
        let discountAmount = 0;
        if (p.discount_type_id) {
          const qDisc = await db.query(
            `SELECT id, code, label, value_off, type FROM discount_types WHERE id = ?`,
            [p.discount_type_id]
          );
          if (!qDisc.rows.length) throw new Error('Tip de discount inexistent');
          const disc = qDisc.rows[0];

          const basePrice = Number(p.price ?? 0);
          discountAmount =
            disc.type === 'percent'
              ? +(basePrice * Number(disc.value_off) / 100).toFixed(2)
              : +Number(disc.value_off);
          if (discountAmount > basePrice) discountAmount = basePrice;

          await db.query(
            `
            INSERT INTO reservation_discounts
              (reservation_id, discount_type_id, discount_amount, discount_snapshot)
            VALUES (?, ?, ?, ?)
            `,
            [newResId, disc.id, discountAmount, Number(disc.value_off)]
          );
        }

        // Pricing
        const netPrice = Number(p.price ?? 0) - discountAmount;
        const listId = p.price_list_id || price_list_id;
        if (!listId) throw new Error('price_list_id lipsă în payload');

        await db.query(
          `
          INSERT INTO reservation_pricing
            (reservation_id, price_value, price_list_id, pricing_category_id, booking_channel, employee_id)
          VALUES (?, ?, ?, ?, ?, 12)
          `,
          [newResId, netPrice, listId, p.category_id, booking_channel]
        );


        // Plată (opțional) – DOAR CARD aici.
        // CASH se face ulterior prin POST /api/reservations/:id/payments/cash (care tipărește și apoi marchează paid)
        if (p.payment_method === 'card' && p.transaction_id) {
          await db.query(
            `
            INSERT INTO payments
              (reservation_id, amount, status, payment_method, transaction_id, timestamp)
            VALUES (?, ?, 'paid', 'card', ?, NOW())
            `,
            [newResId, netPrice, p.transaction_id]
          );
        }
        // Pentru cash: frontend va apela ulterior
        //   POST /api/reservations/:id/payments/cash
        // care tipărește și DOAR apoi marchează plata în DB.

      }
    }

  } catch (err) {
    console.error('Eroare la salvarea rezervării:', err);
    return res.status(500).json({ error: 'Eroare internă la salvare' });
  }

    res.status(201).json({
      ok: true,
      message: 'Rezervare salvată',
      createdReservationIds
    });
});







/* ----------------------------- PAYMENT SUMMARY ----------------------------- */
/**
 * GET /api/reservations/:id/summary
 * Returnează price_value din reservation_pricing și statusul plăților existente.
 */
router.get('/:id/summary', async (req, res) => {
  try {
    const reservationId = Number(req.params.id);
    if (!reservationId) return res.status(400).json({ error: 'reservationId invalid' });

    // --- normalizează răspunsul la SELECT (merge cu mysql2 [rows,fields], cu rows simple sau cu .rows) ---
    const pricingRes = await db.query(
      `SELECT price_value FROM reservation_pricing WHERE reservation_id = ? LIMIT 1`,
      [reservationId]
    );
    const pricingRows = Array.isArray(pricingRes)
      ? (Array.isArray(pricingRes[0]) ? pricingRes[0] : pricingRes)
      : pricingRes?.rows;
    const price_value = pricingRows?.[0]?.price_value ?? null;

    const paidRes = await db.query(
      `SELECT IFNULL(SUM(CASE WHEN status='paid' THEN amount ELSE 0 END),0) AS paid_amount
       FROM payments WHERE reservation_id = ?`,
      [reservationId]
    );
    const paidRows = Array.isArray(paidRes)
      ? (Array.isArray(paidRes[0]) ? paidRes[0] : paidRes)
      : paidRes?.rows;
    const paid_amount = paidRows?.[0]?.paid_amount ?? 0;

    res.json({
      reservationId,
      price: Number(price_value || 0),
      amountPaid: Number(paid_amount || 0),
      paid: Number(price_value || 0) > 0 ? Number(paid_amount) >= Number(price_value) : paid_amount > 0
    });
  } catch (err) {
    console.error('[GET /api/reservations/:id/summary]', err);
    res.status(500).json({ error: 'Eroare la summary' });
  }
});



/* ----------------------------- PAY CASH ----------------------------- */
/* POST /api/reservations/:id/payments/cash
 * 1) citește suma rămasă
 * 2) încearcă tipărire fiscală (FISCAL_PRINTER_URL)
 * 3) doar la succes inserează plata cu status='paid'
 */
router.post('/:id/payments/cash', async (req, res) => {
  try {
    const reservationId = Number(req.params.id);
    if (!reservationId) return res.status(400).json({ error: 'reservationId invalid' });

    const employeeId = req.body?.employeeId || null;

    // 1) suma datorată
    const pricingRes = await db.query(
      `SELECT price_value FROM reservation_pricing WHERE reservation_id = ? LIMIT 1`,
      [reservationId]
    );
    const pricingRows = Array.isArray(pricingRes)
      ? (Array.isArray(pricingRes[0]) ? pricingRes[0] : pricingRes)
      : pricingRes?.rows;
    const price_value = pricingRows?.[0]?.price_value;
    if (price_value == null) return res.status(404).json({ error: 'Preț lipsă pentru rezervare' });

    const paidRes = await db.query(
      `SELECT IFNULL(SUM(CASE WHEN status='paid' THEN amount ELSE 0 END),0) AS paid_amount
       FROM payments WHERE reservation_id = ?`,
      [reservationId]
    );
    const paidRows = Array.isArray(paidRes)
      ? (Array.isArray(paidRes[0]) ? paidRes[0] : paidRes)
      : paidRes?.rows;
    const alreadyPaid = Number(paidRows?.[0]?.paid_amount || 0);
    const amount = Number(price_value) - alreadyPaid;

    if (amount <= 0) {
      return res.status(409).json({ error: 'Rezervare deja achitată' });
    }

    // 2) TRIMITE BONUL la fiscal (respectăm ENV și punem timeout)
    if (!FISCAL_ON) {
      return res.status(503).json({ error: 'FISCAL printing disabled', printed: false });
    }
    if (!FISCAL_URL) {
      return res.status(503).json({ error: 'FISCAL_PRINTER_URL not set', printed: false });
    }

    const customDesc = (req.body && req.body.description) ? String(req.body.description).trim() : '';
    const receiptPayload = {
      reservationId,
      amount,
      description: customDesc || `Rezervare #${reservationId}`
    };
    const r = await fetch(FISCAL_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(receiptPayload),
      signal: AbortSignal.timeout(FISCAL_TO)
    });

    const raw = await r.text();
    let j;
    try { j = JSON.parse(raw); } catch { j = { raw }; }

    const fiscalOk =
      r.ok && (j?.ok === true || j?.printed === true || j?.status === 'ok');

    if (!fiscalOk) {
      const code = j?.code ?? j?.errorCode ?? null;
      const message = j?.message ?? j?.error ?? 'Fiscal print failed';
      // NU inserăm plata, întoarcem eroare la client
      return res.status(502).json({
        error: message,
        code,
        printed: false,
        details: j
      });
    }

    // 3) doar acum înregistrăm plata ca PAID
    await db.query(
      `INSERT INTO payments (reservation_id, amount, status, payment_method, transaction_id, timestamp, collected_by)
       VALUES (?, ?, 'paid', 'cash', NULL, NOW(), ?)`,
      [reservationId, amount, employeeId]
    );

    return res.json({ ok: true, reservationId, amount, printed: true });
  } catch (err) {
    console.error('[POST /reservations/:id/payments/cash]', err);
    return res.status(500).json({ error: 'Eroare la încasare cash' });
  }
});






/* ----------------------------- BACKUP LIST ----------------------------- */

router.get('/backup', async (req, res) => {
  try {
    const { trip_id } = req.query;
    const query = `
      SELECT b.id AS backup_id, b.reservation_id, b.seat_id, s.label, b.trip_id, b.backup_time,
             p.name AS passenger_name, p.phone
      FROM reservations_backup b
      LEFT JOIN people p ON b.person_id = p.id
      LEFT JOIN seats s ON b.seat_id = s.id
      ${trip_id ? 'WHERE b.trip_id = ?' : ''}
      ORDER BY b.backup_time DESC
    `;
    const result = await db.query(query, trip_id ? [trip_id] : []);
    res.json(result.rows);
  } catch (err) {
    console.error('Eroare la interogarea backupurilor:', err);
    res.status(500).json({ error: 'Eroare la interogarea backupurilor' });
  }
});

/* ----------------------------- DELETE by composite ----------------------------- */

router.post('/delete', async (req, res) => {
  const { seat_id, trip_id } = req.body;
  const boardStationId = parseStationId(req.body.board_station_id);
  const exitStationId = parseStationId(req.body.exit_station_id);

  if (!seat_id || !trip_id || boardStationId === null || exitStationId === null) {
    return res.status(400).json({ error: 'Parametri lipsă' });
  }

  try {
    const result = await db.query(
      `
      DELETE FROM reservations
      WHERE seat_id = ? AND trip_id = ? AND board_station_id = ? AND exit_station_id = ?
      `,
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

/* ----------------------------- DELETE by id ----------------------------- */

router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await db.query('DELETE FROM reservations WHERE id = ?', [id]);
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Rezervarea nu a fost găsită' });
    }
    res.json({ success: true });
  } catch (err) {
    console.error('Eroare la DELETE /reservations/:id', err);
    res.status(500).json({ error: 'Eroare internă la ștergere' });
  }
});

/* ----------------------------- MOVE TO OTHER TRIP ----------------------------- */

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
    observations, // opțional
  } = req.body;

  const parsedBoardId = parseStationId(board_station_id);
  const parsedExitId = parseStationId(exit_station_id);

  if (!old_reservation_id || !new_trip_id || !new_seat_id || parsedBoardId === null || parsedExitId === null) {
    return res.status(400).json({ error: 'Missing required data' });
  }

  try {
    // info trip nou + stații
    const tripInfoRes = await db.query('SELECT route_id FROM trips WHERE id = ?', [new_trip_id]);
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

    // 1. backup rezervare veche
    await db.query(
      `
      INSERT INTO reservations_backup (reservation_id, trip_id, seat_id, label, person_id)
      SELECT id, trip_id, seat_id, '', person_id FROM reservations WHERE id = ?
      `,
      [old_reservation_id]
    );

    // 2. anulare rezervare veche
    const updateRes = await db.query(
      `UPDATE reservations SET status = 'cancelled' WHERE id = ?`,
      [old_reservation_id]
    );
    if (updateRes.rowCount === 0) {
      return res.status(404).json({ error: 'Rezervarea veche nu a fost găsită' });
    }

    // 3. persoana
    let person_id;
    if (phone) {
      const personRes = await db.query(`SELECT id FROM people WHERE phone = ?`, [phone]);
      if (personRes.rows.length) {
        person_id = personRes.rows[0].id;
      } else {
        const ins = await db.query(`INSERT INTO people (name, phone) VALUES (?, ?)`, [name || '', phone]);
        person_id = ins.insertId;
      }
    } else {
      const oldRes = await db.query(`SELECT person_id FROM reservations WHERE id = ?`, [old_reservation_id]);
      person_id = oldRes.rows[0]?.person_id;
    }

    // 4. verifică coliziune pe noul loc/segment
    const overlapRes = await db.query(
      `
      SELECT board_station_id, exit_station_id
      FROM reservations
      WHERE trip_id = ? AND seat_id = ? AND status = 'active'
      `,
      [new_trip_id, new_seat_id]
    );

    const hasOverlap = overlapRes.rows.some((r) => {
      const rBoard = getStationIndex(stopsInfo, r.board_station_id);
      const rExit = getStationIndex(stopsInfo, r.exit_station_id);
      return Math.max(newBoardIndex, rBoard) < Math.min(newExitIndex, rExit);
    });

    if (hasOverlap) {
      return res.status(400).json({ error: 'Loc deja ocupat pe segmentul respectiv!' });
    }

    // 5. rezervare nouă
    const insRes = await db.query(
      `
      INSERT INTO reservations
        (trip_id, seat_id, person_id, board_station_id, exit_station_id, observations, status, created_by)
      VALUES (?, ?, ?, ?, ?, ?, 'active', ?)
      `,
      [new_trip_id, new_seat_id, person_id, boardStationId, exitStationId, observations || null, 1]
    );
    const newReservationId = insRes.insertId;

    // 6. copiere pricing din vechea rezervare (booking_channel actualizat)
    await db.query(
      `
      INSERT INTO reservation_pricing
        (reservation_id, price_value, price_list_id, pricing_category_id, booking_channel, employee_id)
      SELECT ?, price_value, price_list_id, pricing_category_id, ?, employee_id
      FROM reservation_pricing
      WHERE reservation_id = ?
      `,
      [newReservationId, booking_channel, old_reservation_id]
    );

    res.json({ success: true, new_reservation_id: newReservationId });
  } catch (err) {
    console.error('Eroare la mutare pe alt trip:', err);
    res.status(500).json({ error: 'Eroare la mutare pe altă cursă' });
  }
});

/* ----------------------------- CONFLICT CHECK ----------------------------- */
/**
 * GET /api/reservations/conflict?person_id=..&date=YYYY-MM-DD&time=HH:MM&board_station_id=..&exit_station_id=..
 */
router.get('/conflict', async (req, res) => {
  const { person_id: qPersonId, date, time } = req.query;
  const boardStationId = parseStationId(req.query.board_station_id);
  const exitStationId = parseStationId(req.query.exit_station_id);

  if (!date || !time || boardStationId === null || exitStationId === null) {
    return res.status(400).json({ error: 'Lipsește date/stații/time' });
  }

  try {
    const pid = Number(qPersonId);
    if (!Number.isInteger(pid) || pid <= 0) {
      return res.status(400).json({ error: 'person_id lipsă sau invalid' });
    }
    const person_id = pid;

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
      WHERE r.person_id = ?
        AND t.date      = ?
        AND r.status    = 'active'
        AND TIME_FORMAT(t.time, '%H:%i') <> ?
    `;

    const result = await db.query(sql, [person_id, date, time]);

    const conflictInfos = [];
    for (const r of result.rows) {
      const stopsInfo = await getStops(r.route_id);
      const iOldBoard = getStationIndex(stopsInfo, r.board_station_id);
      const iOldExit = getStationIndex(stopsInfo, r.exit_station_id);
      const iNewBoard = getStationIndex(stopsInfo, boardStationId);
      const iNewExit = getStationIndex(stopsInfo, exitStationId);

      if ([iOldBoard, iOldExit, iNewBoard, iNewExit].includes(-1)) continue;

      const overlap =
        iOldBoard < iOldExit &&
        iNewBoard < iNewExit &&
        Math.max(iOldBoard, iNewBoard) <= Math.min(iOldExit, iNewExit);

      if (overlap) conflictInfos.push(r);
    }

    res.json({
      conflict: conflictInfos.length > 0,
      infos: conflictInfos.map((r) => ({
        id: r.reservation_id,
        route: r.route_name,
        time: r.time,
        seatLabel: r.seat_label,
        board_station_id: r.board_station_id,
        exit_station_id: r.exit_station_id,
      })),
    });
  } catch (err) {
    console.error('Eroare la /reservations/conflict:', err);
    res.status(500).json({ error: 'server error' });
  }
});




// POST /api/reservations/move
router.post('/move', async (req, res) => {
  try {
    const {
      reservation_id,     // dacă muți o rezervare existentă
      from_seat_id,
      to_seat_id,
      trip_id,
      trip_vehicle_id,    // dacă îl știi; altfel îl obții din seats/trip_seats
      board_station_id,
      exit_station_id
    } = req.body;

    if (!reservation_id || !to_seat_id || !trip_id) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // exemplu simplu; adaptează la schema ta (poți folosi și tranzacție)
    await db.query(
      `UPDATE reservations
         SET seat_id = ?, trip_id = ?, board_station_id = ?, exit_station_id = ?
       WHERE id = ?`,
      [to_seat_id, trip_id, board_station_id || null, exit_station_id || null, reservation_id]
    );

    return res.json({ ok: true });
  } catch (err) {
    console.error('[POST /api/reservations/move] error:', err);
    return res.status(500).json({ error: 'internal' });
  }
});





module.exports = router;
