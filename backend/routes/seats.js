const express = require('express');
const router = express.Router();
const db = require('../db');


const { requireAuth, requireRole } = require('../middleware/auth');

// ✅ Acces: admin, operator_admin, agent (NU driver)
router.use(requireAuth, requireRole('admin', 'operator_admin', 'agent'));



console.log('[ROUTER LOADED] routes/seats.js');

// ==================== Funcții auxiliare ====================
const buildStopLookups = rows => {
  const indexById = new Map();
  rows.forEach((row, idx) => indexById.set(String(row.station_id), idx));
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

// ==================== GET /api/seats ====================
router.get('/', async (req, res) => {
  const { route_id, date, time } = req.query;
  const boardStationId = parseStationId(req.query.board_station_id);
  const exitStationId = parseStationId(req.query.exit_station_id);
  console.log('[GET /api/seats]', { route_id, date, time, boardStationId, exitStationId });

  if (!route_id || !date || !time || boardStationId === null || exitStationId === null)
    return res.status(400).json({ error: 'Parametri insuficienți' });

  try {
    // 🔹 Caută trip-ul
    const { rows: tripRows } = await db.query(
      `SELECT * FROM trips
        WHERE route_id = ?
          AND date = DATE(?)
          AND TIME(time) = TIME(?)`,
      [route_id, date, time]
    );
    console.log('[seats] trips found:', tripRows.length, 'for', { route_id, date, time });
    if (!tripRows.length) {
      console.log('[seats] no trip -> empty diagram');
      return res.json([]);
    }

    const trip = tripRows[0];

    // 🔹 Vehicul principal
    const { rows: principalRows } = await db.query(
      `SELECT id AS vehicle_id, name AS vehicle_name, plate_number FROM vehicles WHERE id = ?`,
      [trip.vehicle_id]
    );
    const principal = principalRows[0];
    if (!principal) {
      return res.status(404).json({ error: 'Trip fără vehicul principal' });
    }
    principal.is_primary = true;
    // 🔹 Dubluri
    const { rows: dubluriRows } = await db.query(
      `SELECT v.id AS vehicle_id, v.name AS vehicle_name, v.plate_number
         FROM trip_vehicles tv
         JOIN vehicles v ON v.id = tv.vehicle_id
        WHERE tv.trip_id = ? AND tv.is_primary = 0`,
      [trip.id]
    );
    const dubluri = dubluriRows.map(r => ({ ...r, is_primary: false }));

    const allVehicles = [principal, ...dubluri];

    // 🔹 Stațiile
    const { rows: stopsRows } = await db.query(
      `SELECT rs.station_id, s.name
         FROM route_stations rs
         JOIN stations s ON s.id = rs.station_id
        WHERE rs.route_id = ?
        ORDER BY rs.sequence`,
      [route_id]
    );

    if (!stopsRows.length)
      return res.status(400).json({ error: 'Rutele nu au stații definite' });

    const lookups = buildStopLookups(stopsRows);
    const boardIndex = getStationIndex(lookups, boardStationId);
    const exitIndex = getStationIndex(lookups, exitStationId);
    if (boardIndex === -1 || exitIndex === -1 || boardIndex >= exitIndex)
      return res.status(400).json({ error: 'Segment invalid' });

    // 🔹 Pentru fiecare vehicul
    for (const veh of allVehicles) {
      // Locurile
      const { rows: seatRows } = await db.query(
        `SELECT s.*, v.name AS vehicle_name, v.plate_number
           FROM seats s
           JOIN vehicles v ON s.vehicle_id = v.id
          WHERE s.vehicle_id = ?
          ORDER BY s.seat_number`,
        [veh.vehicle_id]
      );
      console.log('[seats] seats for vehicle:', veh.vehicle_id, 'count=', seatRows.length);

      // Rezervări
      const { rows: resRows } = await db.query(
        `        SELECT
           r.id AS reservation_id,
           r.person_id,
           r.seat_id,
           r.board_station_id,
           r.exit_station_id,
           p.name,
           p.phone,
           r.observations,
           r.status,
           /* dacă există minim o plată PAID => 'paid' */
           (
             SELECT CASE WHEN SUM(p2.status='paid')>0 THEN 'paid' ELSE NULL END
             FROM payments p2
             WHERE p2.reservation_id = r.id
           ) AS payment_status,
           /* metoda ultimei plăți PAID (cash/card) */
           (
             SELECT p3.payment_method
             FROM payments p3
             WHERE p3.reservation_id = r.id AND p3.status='paid'
             ORDER BY p3.timestamp DESC, p3.id DESC
             LIMIT 1
           ) AS payment_method
         FROM reservations r
         JOIN people p ON p.id = r.person_id
        WHERE r.trip_id = ?
          AND r.status <> 'cancelled'
`,
        [trip.id]
      );

      const seatReservations = {};
      for (const r of resRows) {
        if (!seatReservations[r.seat_id]) seatReservations[r.seat_id] = [];
        seatReservations[r.seat_id].push(r);
      }

      veh.seats = seatRows.map(seat => {
        const reservations = seatReservations[seat.id] || [];
        const allPassengers = reservations.map(r => ({
          person_id: r.person_id,
          reservation_id: r.reservation_id,
          name: r.name,
          phone: r.phone,
          board_station_id: r.board_station_id,
          exit_station_id: r.exit_station_id,
          observations: r.observations || '',
          status: r.status,
          payment_status: r.payment_status || null,
          payment_method: r.payment_method || null,
        }));


        const active = reservations.filter(r => r.status === 'active');
        let status = 'free';
        let isAvailable = true;
        for (const r of active) {
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

        return { ...seat, is_available: isAvailable, status, passengers: allPassengers };
      });
    }

    res.json(allVehicles);
  } catch (err) {
    console.error('Eroare seats API:', err);
    res.status(500).json({ error: 'Eroare internă seats' });
  }
});

// ==================== GET /api/seats/:vehicle_id ====================
router.get('/:vehicle_id', async (req, res) => {
  const { vehicle_id } = req.params;
  let { route_id, date, time } = req.query;
  const boardStationId = parseStationId(req.query.board_station_id);
  const exitStationId = parseStationId(req.query.exit_station_id);
  if (time === 'null') time = null;

  if (!route_id || !date || !time || boardStationId === null || exitStationId === null)
    return res.status(400).json({ error: 'Parametri insuficienți' });

  try {
    const { rows: stopsRows } = await db.query(
      `SELECT rs.station_id, s.name
         FROM route_stations rs
         JOIN stations s ON s.id = rs.station_id
        WHERE rs.route_id = ?
        ORDER BY rs.sequence`,
      [route_id]
    );

    if (!stopsRows.length)
      return res.status(400).json({ error: 'Rutele nu au stații definite' });

    const lookups = buildStopLookups(stopsRows);
    const boardIndex = getStationIndex(lookups, boardStationId);
    const exitIndex = getStationIndex(lookups, exitStationId);
    if (boardIndex === -1 || exitIndex === -1 || boardIndex >= exitIndex)
      return res.status(400).json({ error: 'Segment invalid' });

    const { rows: seatRows } = await db.query(
      `SELECT s.*, v.name AS vehicle_name, v.plate_number
         FROM seats s
         JOIN vehicles v ON s.vehicle_id = v.id
        WHERE s.vehicle_id = ?
        ORDER BY s.seat_number`,
      [vehicle_id]
    );

    const { rows: tripRows } = await db.query(
      `SELECT id FROM trips
         WHERE route_id = ?
           AND date = DATE(?)
           AND TIME(time) = TIME(?)`,
      [route_id, date, time]
    );

    console.log('[seats/:vehicle] trips found:', tripRows.length, 'for', { route_id, date, time });
    if (!tripRows.length)
      return res.json(
        seatRows.map(seat => ({
          ...seat,
          is_available: true,
          status: 'free',
          passengers: [],
        }))
      );

    const trip_id = tripRows[0].id;

    console.log('[seats/:vehicle] folosim procedura sp_free_seats()', {
  trip_id,
  boardStationId,
  exitStationId
});

// Apelează procedura stocată
const callRes = await db.query('CALL sp_free_seats(?, ?, ?)', [
  trip_id,
  boardStationId,
  exitStationId
]);

// ✅ MariaDB returnează [ [rows], metadata ]
let freeRows = [];
if (Array.isArray(callRes?.rows)) {
  freeRows = Array.isArray(callRes.rows[0]) ? callRes.rows[0] : callRes.rows;
} else if (Array.isArray(callRes)) {
  freeRows = Array.isArray(callRes[0]) ? callRes[0] : [];
}

console.log('[sp_free_seats rezultat]', freeRows?.length, 'locuri libere');


// 🔹 Preluăm ordinea stațiilor pentru cursa curentă (trip_stations)
const { rows: tripStations } = await db.query(
  'SELECT station_id, sequence FROM trip_stations WHERE trip_id = ? ORDER BY sequence',
  [trip_id]
);
const stationSeq = {};
for (const s of tripStations) stationSeq[s.station_id] = s.sequence;

const boardSeq = stationSeq[boardStationId];
const exitSeq = stationSeq[exitStationId];


// 🔹 preluăm rezervările active pentru cursa curentă
const { rows: reservations } = await db.query(`
  SELECT
    r.id AS reservation_id,
    r.person_id,
    r.seat_id,
    r.board_station_id,
    r.exit_station_id,
    p.name,
    p.phone,
    r.observations,
    r.status,
    (
      SELECT CASE WHEN SUM(p2.status='paid') > 0 THEN 'paid' ELSE NULL END
      FROM payments p2
      WHERE p2.reservation_id = r.id
    ) AS payment_status,
    (
      SELECT p3.payment_method
      FROM payments p3
      WHERE p3.reservation_id = r.id AND p3.status='paid'
      ORDER BY p3.timestamp DESC, p3.id DESC
      LIMIT 1
    ) AS payment_method
  FROM reservations r
  JOIN people p ON p.id = r.person_id
  WHERE r.trip_id = ?
    AND r.status <> 'cancelled'
`, [trip_id]);

// 🔹 grupăm pasagerii pe loc
const seatReservations = {};
for (const r of reservations) {
  if (!seatReservations[r.seat_id]) seatReservations[r.seat_id] = [];
  seatReservations[r.seat_id].push(r);
}


// Creează un set cu toate id-urile de locuri libere
const freeSet = new Set(freeRows.map(r => r.id));


// 🔹 Marchează locurile corect: free / partial / full
const result = seatRows.map(seat => {
  const passengers = seatReservations[seat.id] || [];
  let status = 'free';
  let isAvailable = true;

  for (const r of passengers.filter(p => p.status === 'active')) {
    const rBoardSeq = stationSeq[r.board_station_id];
    const rExitSeq = stationSeq[r.exit_station_id];

    // verificăm dacă segmentele se suprapun
    const overlap = !(rExitSeq <= boardSeq || rBoardSeq >= exitSeq);
    if (overlap) {
      isAvailable = false;
      status = 'partial';
      // dacă rezervarea acoperă complet segmentul selectat => full
      if (rBoardSeq <= boardSeq && rExitSeq >= exitSeq) {
        status = 'full';
        break;
      }
    }
  }

  return {
    ...seat,
    is_available: isAvailable,
    status,
    passengers
  };
});


console.log('[seats rezultat final]', JSON.stringify(result.slice(0, 3), null, 2));

res.json(result);
console.log('[Seat statuses]', result.map(s => ({ label: s.label, status: s.status })).slice(0, 10));

  } catch (err) {
    console.error('Eroare la verificarea locurilor:', err);
    res.status(500).json({ error: 'Eroare internă la verificarea locurilor' });
  }
});

module.exports = router;
