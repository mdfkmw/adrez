const express = require('express');
const router  = express.Router();
const db      = require('../db');

// ✅ Returnează lista agențiilor din tabela `agencies`
router.get('/', async (_req, res) => {
  try {
    const result = await db.query(
      'SELECT id, name FROM agencies ORDER BY name'
    );
    res.json(result.rows);
  } catch (err) {
    console.error('[GET /api/agencies]', err);
    res.status(500).json({ error: 'Eroare la interogarea bazei de date' });
  }
});

module.exports = router;
