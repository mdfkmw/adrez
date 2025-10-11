const express = require('express');
const router = express.Router();
const db = require('../db'); // adaptează dacă ai alt path

// GET /api/operators
router.get('/', async (req, res) => {
  try {
    const result = await db.query(
      `SELECT id, name, pos_endpoint, theme_color FROM operators ORDER BY name`
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Eroare la GET /api/operators:', err);
    res.status(500).json({ error: 'Eroare internă operators' });
  }
});

module.exports = router;
