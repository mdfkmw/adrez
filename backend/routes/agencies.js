const express = require('express');
const router  = express.Router();
const db      = require('../db');

router.get('/', async (_req, res) => {
  try {
    const { rows } = await db.query(
      'SELECT id, name FROM agencies ORDER BY name'
    );
    res.json(rows);
  } catch (err) {
    console.error('[GET /api/agencies]', err);
    res.status(500).json({ error: 'db error' });
  }
});

module.exports = router;
