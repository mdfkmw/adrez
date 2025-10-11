const express = require('express');
const router  = express.Router();
const db      = require('../db');

// GET /api/stations
router.get('/', async (_req, res) => {
  const { rows } = await db.query('SELECT * FROM stations ORDER BY name');
  res.json(rows);
});

// POST /api/stations
router.post('/', async (req, res) => {
  const { name, locality, county, latitude, longitude } = req.body;
  const lat = latitude === '' ? null : Number(latitude);
const lon = longitude  === '' ? null : Number(longitude);

  const { rows } = await db.query(
    `INSERT INTO stations (name, locality, county, latitude, longitude)
     VALUES ($1,$2,$3,$4,$5) RETURNING *`,
    [name, locality, county, lat, lon]
  );
  res.status(201).json(rows[0]);
});

// PUT /api/stations/:id
router.put('/:id', async (req, res) => {
  const { name, locality, county, latitude, longitude } = req.body;
  const lat = latitude === '' ? null : Number(latitude);
  const lon = longitude === '' ? null : Number(longitude);
  const { rows } = await db.query(
    `UPDATE stations
       SET name=$2, locality=$3, county=$4,
           latitude=$5, longitude=$6, updated_at=now()
     WHERE id=$1
     RETURNING *`,
    [req.params.id, name, locality, county, lat, lon]
  );
  if (!rows.length) return res.status(404).json({ error: 'not found' });
  res.json(rows[0]);
});

// DELETE /api/stations/:id
router.delete('/:id', async (req, res) => {
  await db.query('DELETE FROM stations WHERE id = $1', [req.params.id]);
  res.sendStatus(204);
});

module.exports = router;
