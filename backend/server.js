// Importă frameworkul Express – esențial pentru crearea aplicației backend
const express = require('express');

// Importă modulul CORS – permite accesul din altă origine (frontendul tău React)
const cors = require('cors');

// Creează instanța aplicației Express
const app = express();

// Conectează la baza de date – fișierul db.js conține configurarea PostgreSQL
const pool = require('./db');

// Încarcă rutele definite în fișierul routes.js (pentru /api/routes)
const routesApi = require('./routes/routes');

// Încarcă fișierele pentru rutele individuale
const seatsRoutes = require('./routes/seats');             // rute legate de locuri
const reservationsRoutes = require('./routes/reservations'); // rezervări
const tripRoutes = require('./routes/trips');              // curse (trips)
const tripVehiclesRoutes = require('./routes/tripVehicles');
const peopleRouter = require('./routes/people');
const seatsRouter = require('./routes/seats');
const employeesRouter = require('./routes/employees');
const operatorsRouter = require('./routes/operators');
const tripAssignmentsRouter = require('./routes/tripAssignments');
const routeTimeDiscountsRouter = require('./routes/routeTimeDiscounts');
const discountTypesRouter = require('./routes/discountTypes');
const priceListsRouter = require('./routes/priceLists');
const reportsRouter     = require('./routes/reports');
const agenciesRouter = require('./routes/agencies');
const stationsRouter = require('./routes/stations');
const cashRouter = require('./routes/cash');

// ✅ Activează CORS pentru a permite comunicarea între frontend (localhost:5173) și backend (localhost:5000)
app.use(cors({
  origin: '*',               // adresa aplicației frontend React (Vite)
  methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'], // metodele HTTP permise
  allowedHeaders: ['Content-Type'],              // ce tip de headeruri sunt permise
}));

// ✅ Middleware-ul Express pentru a interpreta automat datele JSON din body-ul requestului
app.use(express.json());


// ✅ Înregistrează rutele definite în fișierele externe
// Toate aceste rute vor fi prefixate cu /api/[nume], de ex: /api/seats/:vehicleId
app.use('/api/seats', seatsRoutes);               // Operații legate de locuri (GET locuri pentru un vehicul/trip)
app.use('/api/reservations', reservationsRoutes); // Creare, backup și restaurare rezervări
app.use('/api/routes', routesApi);                // Rute (listează rutele disponibile, opriri etc.)
app.use('/api/vehicles', require('./routes/vehicles')); // Listează vehiculele disponibile
app.use('/api/trips/:tripId/vehicles', tripVehiclesRoutes);
app.use('/api/trips', require('./routes/trips'));       // Operații pe curse (trip summary, asignare vehicul etc.)
app.use('/api/trips', tripRoutes);                      // redundanță (poate fi eliminată dacă ai deja linia de mai sus)
app.use('/api', require('./routes/blacklist'));
app.use('/api/people', peopleRouter);
app.use('/api/seats', seatsRouter);
app.use('/api/employees', employeesRouter);
app.use('/api/operators', operatorsRouter);
app.use('/api/trip_assignments', tripAssignmentsRouter);
app.use('/api/routes_order', require('./routes/routesOrder'));
app.use('/api', routeTimeDiscountsRouter);
app.use('/api/discount-types', discountTypesRouter);
app.use('/api', priceListsRouter);
app.use('/api/reports', reportsRouter);
app.use('/api/agencies', agenciesRouter);
app.use('/api/stations', stationsRouter);
app.use('/api/cash', cashRouter);


// 🔁 API mutare pasager în alt loc
app.post('/api/reservations/move', async (req, res) => {
  const { from_seat_id, to_seat_id, trip_id } = req.body;
  const boardStationRaw = req.body.board_station_id;
  const exitStationRaw = req.body.exit_station_id;
  const boardStationId = boardStationRaw === undefined || boardStationRaw === null || boardStationRaw === ''
    ? null
    : Number(boardStationRaw);
  const exitStationId = exitStationRaw === undefined || exitStationRaw === null || exitStationRaw === ''
    ? null
    : Number(exitStationRaw);

  if (!from_seat_id || !to_seat_id || !trip_id || boardStationId === null || exitStationId === null || Number.isNaN(boardStationId) || Number.isNaN(exitStationId)) {
    return res.status(400).json({ error: 'Parametri lipsă pentru mutarea rezervării' });
  }

  try {
    const existing = await pool.query(
      `SELECT * FROM reservations
        WHERE seat_id = $1 AND trip_id = $2 AND status = $5
          AND board_station_id = $3 AND exit_station_id = $4`,
      [from_seat_id, trip_id, boardStationId, exitStationId, 'active']
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({ error: 'Rezervarea nu a fost găsită pentru mutare' });
    }

    const reservation = existing.rows[0];

    // actualizează doar seat_id
    await pool.query(
      'UPDATE reservations SET seat_id = $1 WHERE id = $2',
      [to_seat_id, reservation.id]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('Eroare la mutarea pasagerului:', err);
    res.status(500).json({ error: 'Eroare la mutarea pasagerului' });
  }
});

app.get('/', (req, res) => {
  res.send('Backend API este pornit şi ascultă pe portul 5000.');
});


// ✅ Pornește serverul pe portul 5000 și afișează un mesaj de confirmare în consolă
const PORT = process.env.PORT || 5000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server backend ascultă pe portul ${PORT}`);
});






