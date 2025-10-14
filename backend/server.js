require('dotenv').config();



// Importă frameworkul Express – esențial pentru crearea aplicației backend
const express = require('express');

// Importă modulul CORS – permite accesul din altă origine (frontendul tău React)
const cors = require('cors');

// Creează instanța aplicației Express
const app = express();

// Conectează la baza de date – fișierul db.js conține configurarea MariaDB (mysql2/promise)
const pool = require('./db');

// Încarcă fișierele pentru rutele individuale
const routesApi = require('./routes/routes');
const seatsRoutes = require('./routes/seats');
const reservationsRoutes = require('./routes/reservations');
const tripRoutes = require('./routes/trips');
const tripVehiclesRoutes = require('./routes/tripVehicles');
const peopleRouter = require('./routes/people');
const employeesRouter = require('./routes/employees');
const operatorsRouter = require('./routes/operators');
const tripAssignmentsRouter = require('./routes/tripAssignments');
const routeTimeDiscountsRouter = require('./routes/routeTimeDiscounts');
const discountTypesRouter = require('./routes/discountTypes');
const priceListsRouter = require('./routes/priceLists');
const reportsRouter = require('./routes/reports');
const agenciesRouter = require('./routes/agencies');
const stationsRouter = require('./routes/stations');
const cashRouter = require('./routes/cash');
const phonesRoutes = require('./routes/phones');



// ✅ Activează CORS pentru a permite comunicarea între frontend (localhost:5173) și backend (localhost:5000)
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type'],
}));

// ✅ Middleware Express pentru a interpreta automat datele JSON din body-ul requestului
app.use(express.json());


// 🔎 LOG GLOBAL: vezi orice request intră în backend
//app.use((req, res, next) => {
 // console.log(`[REQ] ${req.method} ${req.originalUrl} q=`, req.query || {});
//  next();
//});



// ✅ Înregistrează rutele definite în fișierele externe
app.use('/api/seats', seatsRoutes);
app.use('/api/reservations', reservationsRoutes);
app.use('/api/routes', routesApi);
app.use('/api/vehicles', require('./routes/vehicles'));
//app.use('/api/trips/:tripId/vehicles', tripVehiclesRoutes);
app.use('/api/trips', require('./routes/trips'));
app.use('/api', require('./routes/blacklist'));
app.use('/api/people', peopleRouter);
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
app.use('/api/trips', tripVehiclesRoutes);
app.use('/api/phones', phonesRoutes);


// 🔚 404 logger pentru orice rută negăsită (utile dacă FE lovește alt URL)
app.use((req, res) => {
  console.log(`[404] ${req.method} ${req.originalUrl}`);
  res.status(404).json({ error: 'Not found' });
});

// Test simplu
app.get('/', (req, res) => {
  res.send('Backend API este pornit şi ascultă pe portul 5000.');
});

// ✅ Pornește serverul pe portul 5000
const PORT = process.env.PORT || 5000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Server backend ascultă pe portul ${PORT}`);
});
