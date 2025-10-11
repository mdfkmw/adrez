// routes/seats.js
const express = require('express');
const router = express.Router();
const db = require('../db');

const buildStopLookups = rows => {
  const indexById = new Map();

  rows.forEach((row, idx) => {
    const idKey = String(row.station_id);
    indexById.set(idKey, idx);
  });

  return { indexById };
};

const getStationIndex = (lookups, stationId) => {
  if (stationId === null || stationId === undefined) return -1;
  const idx = lookups.indexById.get(String(stationId));
  return idx === undefined ? -1 : idx;
};

const parseStationId = value => {
  if (value === undefined || value === null || value === '') return null;
  const num = Number(value);
  return Number.isNaN(num) ? null : num;
};


//pentru afisare dubluri in muta pe alta cursa
// GET /api/seats?route_id=...&date=...&time=...&board_station_id=...&exit_station_id=...
router.get('/', async (req, res) => {
  const { route_id, date, time } = req.query;
  const boardStationId = parseStationId(req.query.board_station_id);
  const exitStationId = parseStationId(req.query.exit_station_id);
  // Parametri minimi
  if (!route_id || !date || !time || boardStationId === null || exitStationId === null)
    return res.status(400).json({ error: 'Parametri insuficienți' });

  try {
    // Ia trip-ul
    const tripRes = await db.query(
      `SELECT * FROM trips WHERE route_id = $1 AND date = $2 AND time = $3`,
      [route_id, date, time]
    );
    if (tripRes.rows.length === 0) return res.json([]);

    const trip = tripRes.rows[0];

    // Ia vehiculul principal
    const principalRes = await db.query(
      `SELECT id as vehicle_id, name as vehicle_name, plate_number FROM vehicles WHERE id = $1`,
      [trip.vehicle_id]
    );
    const principal = principalRes.rows[0];
    principal.is_primary = true;

    // Ia dublurile (is_primary = false)
    const dubluriRes = await db.query(
      `SELECT v.id as vehicle_id, v.name as vehicle_name, v.plate_number
         FROM trip_vehicles tv
         JOIN vehicles v ON v.id = tv.vehicle_id
        WHERE tv.trip_id = $1 AND tv.is_primary = FALSE`,
      [trip.id]
    );
    const dubluri = dubluriRes.rows.map(row => ({ ...row, is_primary: false }));

    // Array cu toate vehiculele
    const allVehicles = [principal, ...dubluri];

    // Ia stops (ca în logica ta actuală)
    const stopsRes = await db.query(`
      SELECT rs.station_id, s.name
      FROM   route_stations  rs
      JOIN   stations        s  ON s.id = rs.station_id
      WHERE  rs.route_id = $1
      ORDER  BY rs.sequence
    `, [route_id]);

    const lookups = buildStopLookups(stopsRes.rows);

    if (!stopsRes.rows || !stopsRes.rows.length) {
      return res.status(400).json({ error: 'Rutele nu au stații definite' });
    }

    const boardIndex = getStationIndex(lookups, boardStationId);
    const exitIndex = getStationIndex(lookups, exitStationId);
    if (boardIndex === -1 || exitIndex === -1 || boardIndex >= exitIndex) {
      return res.status(400).json({ error: 'Segment invalid' });
    }

    // Pentru fiecare vehicul, ia seatmap-ul + rezervările (copy-paste din handlerul tău existent!)
    for (const veh of allVehicles) {
      // Ia toate locurile
      const seatRes = await db.query(
        `SELECT s.*, v.name AS vehicle_name, v.plate_number
         FROM seats s
         JOIN vehicles v ON s.vehicle_id = v.id
         WHERE s.vehicle_id = $1
         ORDER BY s.seat_number`,
        [veh.vehicle_id]
      );
      const seats = seatRes.rows;

      // Ia trip_id
      const trip_id = trip.id;

      // Rezervări pentru vehiculul curent
      const reservationsRes = await db.query(
        `SELECT
           r.id                AS reservation_id,
           r.person_id         AS person_id,
           r.seat_id           AS seat_id,
           r.board_station_id,
           r.exit_station_id,
           p.name              AS name,
           p.phone             AS phone,
           r.observations      AS observations,
           r.status            AS status
         FROM reservations r
         JOIN people p ON p.id = r.person_id
         WHERE r.trip_id = $1
           AND r.status <> 'canceled'`,
        [trip_id]
      );

      const seatReservations = {};
      for (const r of reservationsRes.rows) {
        if (!seatReservations[r.seat_id]) seatReservations[r.seat_id] = [];
        seatReservations[r.seat_id].push(r);
      }

      veh.seats = seats.map(seat => {
        const reservations = seatReservations[seat.id] || [];
        const allPassengers = reservations.map(r => ({
          person_id:        r.person_id,
          reservation_id:   r.reservation_id,
          name:             r.name,
          phone:            r.phone,
          board_station_id: r.board_station_id,
          exit_station_id:  r.exit_station_id,
          observations:     r.observations || '',
          status:           r.status
        }));

        const activeReservations = reservations.filter(r => r.status === 'active');

        let status = 'free';
        let isAvailable = true;
        for (const r of activeReservations) {
          const rBoard = getStationIndex(lookups, r.board_station_id);
          const rExit = getStationIndex(lookups, r.exit_station_id);
          const overlap = Math.max(boardIndex, rBoard) < Math.min(exitIndex, rExit);

          if (overlap) {
            isAvailable = false;
            status = 'partial';
            if (rBoard <= boardIndex && rExit >= exitIndex) {
              status = 'full';
              break;
            }
          }
        }
        return {
          ...seat,
          is_available: isAvailable,
          status,
          passengers: allPassengers
        };
      });
    }

    res.json(allVehicles);
  } catch (err) {
    console.error('Eroare seats API:', err);
    res.status(500).json({ error: 'Eroare internă seats' });
  }
});







router.get('/:vehicle_id', async (req, res) => {
  const { vehicle_id } = req.params;
  let { route_id, date, time } = req.query;
  const boardStationId = parseStationId(req.query.board_station_id);
  const exitStationId = parseStationId(req.query.exit_station_id);
  // Tratează string-ul "null" (din query) ca absent
  if (time === 'null') {
    time = null;
  }

  // Verifică parametri esențiali; dacă time e falsy sau null, e invalid
  if (!route_id || !date || !time || boardStationId === null || exitStationId === null) {
    return res.status(400).json({ error: 'Parametri insuficienți' });
  }
  try {
const stopsRes = await db.query(`
  SELECT rs.station_id, s.name
  FROM   route_stations  rs
  JOIN   stations        s  ON s.id = rs.station_id
  WHERE  rs.route_id = $1
  ORDER  BY rs.sequence
`, [route_id]);

const lookups = buildStopLookups(stopsRes.rows);

    if (!stopsRes.rows || !stopsRes.rows.length) {
      return res.status(400).json({ error: 'Rutele nu au stații definite' });
    }

    const boardIndex = getStationIndex(lookups, boardStationId);
    const exitIndex = getStationIndex(lookups, exitStationId);

    if (boardIndex === -1 || exitIndex === -1 || boardIndex >= exitIndex) {
      return res.status(400).json({ error: 'Segment invalid' });
    }

    const seatRes = await db.query(
      `SELECT s.*, v.name AS vehicle_name, v.plate_number
       FROM seats s
       JOIN vehicles v ON s.vehicle_id = v.id
       WHERE s.vehicle_id = $1
       ORDER BY s.seat_number`,
      [vehicle_id]
    );
    const seats = seatRes.rows;

    const tripRes = await db.query(
      `SELECT id FROM trips WHERE route_id = $1 AND date = $2 AND time = $3`,
      [route_id, date, time]
    );
    if (tripRes.rows.length === 0) {
      return res.json(seats.map(seat => ({
        ...seat,
        is_available: true,
        status: 'free',
        passengers: []
      })));
    }
    const trip_id = tripRes.rows[0].id;

    // SELECT cu status inclus!
    const reservationsRes = await db.query(
  `SELECT
     r.id                AS reservation_id,
     r.person_id         AS person_id,
     r.seat_id           AS seat_id,
     r.board_station_id,
     r.exit_station_id,
     p.name              AS name,
     p.phone             AS phone,
     r.observations      AS observations,
     r.status            AS status
   FROM reservations r
   JOIN people p ON p.id = r.person_id
   WHERE r.trip_id = $1
     AND r.status <> 'canceled'`,
  [trip_id]
);

    const seatReservations = {};
    for (const r of reservationsRes.rows) {
      if (!seatReservations[r.seat_id]) seatReservations[r.seat_id] = [];
      seatReservations[r.seat_id].push(r);
    }

    const result = seats.map(seat => {
      const reservations = seatReservations[seat.id] || [];
      // Pasagerii: toți, pentru istoric (frontendul alege ce afișează)
            const allPassengers = reservations.map(r => ({
        person_id:        r.person_id,      // <<< adăugat
        reservation_id:   r.reservation_id,
       name:             r.name,
        phone:            r.phone,
        board_station_id: r.board_station_id,
        exit_station_id:  r.exit_station_id,
        observations:     r.observations || '',
        status:           r.status
      }));

      // FILTRARE activi pentru status vizual și blocare
      const activeReservations = reservations.filter(r => r.status === 'active');

      let status = 'free';
      let isAvailable = true;
      for (const r of activeReservations) {
        const rBoard = getStationIndex(lookups, r.board_station_id);
        const rExit = getStationIndex(lookups, r.exit_station_id);
        const overlap = Math.max(boardIndex, rBoard) < Math.min(exitIndex, rExit);

        if (overlap) {
          isAvailable = false;
          status = 'partial';
          if (rBoard <= boardIndex && rExit >= exitIndex) {
            status = 'full';
            break;
          }
        }
      }

      return {
        ...seat,
        is_available: isAvailable,
        status,
        passengers: allPassengers
      };
    });

    // LOG PENTRU DEBUG (poți șterge după ce ai testat)
    //console.log('--- DEBUG seats API ---');
    //result.forEach(seat => {
    //  console.log(
    //    `Loc ${ seat.label }: status = ${ seat.status } | pasageri=[${
    //  seat.passengers.map(p => p.status).join(', ')
    //}]`
    //  );
    //});
    //console.log('----------------------');

    res.json(result);
  } catch (err) {
    console.error('Eroare la verificarea locurilor:', err);
    res.status(500).json({ error: 'Eroare internă la verificarea locurilor' });
  }
});

module.exports = router;
