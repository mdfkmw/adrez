// routes/vehicles.js
// Importă framework-ul Express pentru a crea rute HTTP
const express = require('express');
// Creează un router Express pentru a defini rutele API
// Creează un router Express pentru a defini rutele disponibile în această secțiune
const router = express.Router();
// Importă conexiunea la baza de date (modulul db)
const db = require('../db');

// Definește ruta GET (ex: listare date)
// Definește o rută GET - folosită pentru a obține date din server
router.get('/', async (req, res) => {
// Folosește blocul try pentru a prinde eventualele erori
// Începe un bloc try-catch pentru tratarea erorilor
  try {
// Execută o interogare SQL folosind conexiunea la baza de date
// Execută o interogare în PostgreSQL folosind modulul 'db'
    const result = await db.query('SELECT * FROM vehicles');
// Trimite răspunsul înapoi către client sub formă de JSON
    res.json(result.rows);
// Prinde orice eroare apărută în blocul try și o tratează corespunzător
  } catch (err) {
// Afișează o eroare în consola backend-ului pentru depanare
    console.error('Eroare la fetch vehicles:', err);
// Răspunde clientului cu un cod de stare HTTP și un mesaj JSON
    res.status(500).json({ error: 'Eroare la fetch vehicles' });
  }
});



// ─────────────────────────────────────────────────────────────
// GET /api/vehicles/:tripId/available
//  ▸ întoarce numai vehiculele OPERATORULUI cursei :tripId
//    care NU sunt deja în trip_vehicles pentru cursa respectivă
// ─────────────────────────────────────────────────────────────
router.get('/:tripId/available', async (req, res) => {
  const { tripId } = req.params;

  try {
    // 1️⃣ operatorul cursei
    const { rows: op } = await db.query(
      `SELECT rs.operator_id
         FROM trips t
         JOIN route_schedules rs ON rs.id = t.route_schedule_id
        WHERE t.id = $1`,
      [tripId]
    );
    if (!op.length) {
      return res.status(404).json({ error: 'Cursa nu există.' });
    }
    const operatorId = op[0].operator_id;

    // 2️⃣ vehicule eligibile
    const { rows } = await db.query(
      `SELECT v.*
         FROM vehicles v
        WHERE v.operator_id = $1
          AND v.id NOT IN (
            SELECT vehicle_id FROM trip_vehicles WHERE trip_id = $2
          )
        ORDER BY v.name`,
      [operatorId, tripId]
    );

    res.json(rows);
  } catch (err) {
    console.error('Eroare la /available →', err);
    res.status(500).json({ error: 'Eroare internă' });
  }
});


// Exportă routerul pentru a fi folosit în server.js
module.exports = router;
