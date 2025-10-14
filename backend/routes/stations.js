const express = require('express');
const router  = express.Router();
const db      = require('../db');

// ==================== GET /api/stations ====================
router.get('/', async (_req, res) => {
  try {
    const { rows } = await db.query('SELECT * FROM stations ORDER BY name');
    res.json(rows);
  } catch (err) {
    console.error('GET /api/stations error:', err);
    res.status(500).json({ error: 'Eroare la citirea stațiilor' });
  }
});

// ==================== POST /api/stations ====================
router.post('/', async (req, res) => {
  const { name, locality, county, latitude, longitude } = req.body;
  const lat = (latitude === '' || latitude === undefined) ? null : Number(latitude);
  const lon = (longitude === '' || longitude === undefined) ? null : Number(longitude);
  const loc = (locality === '') ? null : locality;
  const cty = (county === '') ? null : county;

  try {
const ins = await db.query(
  `INSERT INTO stations (name, locality, county, latitude, longitude)
   VALUES (?, ?, ?, ?, ?)`,
  [name, loc, cty, lat, lon]
);
const { insertId } = ins; // oferit de adaptorul din db.js
const { rows: st } = await db.query('SELECT * FROM stations WHERE id = ?', [insertId]);
res.status(201).json(st[0]);

  } catch (err) {
    console.error('POST /api/stations error:', err);
    res.status(500).json({ error: 'Eroare la adăugarea stației' });
  }
});

// ==================== PUT /api/stations/:id ====================
router.put('/:id', async (req, res) => {
  const { name, locality, county, latitude, longitude } = req.body;
  const lat = latitude === '' ? null : Number(latitude);
  const lon = longitude === '' ? null : Number(longitude);

  try {
    await db.query(
      `UPDATE stations
          SET name = ?, locality = ?, county = ?,
              latitude = ?, longitude = ?, updated_at = NOW()
        WHERE id = ?`,
      [name, locality, county, lat, lon, req.params.id]
    );

    const { rows } = await db.query('SELECT * FROM stations WHERE id = ?', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Stația nu a fost găsită' });
    res.json(rows[0]);
  } catch (err) {
    console.error('PUT /api/stations/:id error:', err);
    res.status(500).json({ error: 'Eroare la actualizarea stației' });
  }
});

// ==================== DELETE /api/stations/:id ====================
router.delete('/:id', async (req, res) => {
  try {
    await db.query('DELETE FROM stations WHERE id = ?', [req.params.id]);
    res.sendStatus(204);
  } catch (err) {
    console.error('DELETE /api/stations/:id error:', err);
    res.status(500).json({ error: 'Eroare la ștergerea stației' });
  }
});

module.exports = router;
