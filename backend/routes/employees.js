const express = require('express');
const router = express.Router();
const db = require('../db'); // your PG client




// READ: list employees, cu filtrare după operator, rol şi stare activă
// READ: list employees, cu două moduri (admin vs filtrare agent)
router.get('/', async (req, res) => {
  const { operator_id, agency_id } = req.query;
  try {
    // Caz 1: fără query params → admin page
    if (!operator_id && !agency_id) {
      const { rows } = await db.query(
        'SELECT * FROM employees ORDER BY id ASC'
      );
      return res.json(rows);
    }

    // Caz 2: filtrare AgentSelect
    const clauses = [];
    const params  = [];

    if (operator_id) {
      params.push(operator_id);
      clauses.push(`operator_id = $${params.length}`);
    }
    if (agency_id) {
      params.push(agency_id);
      clauses.push(`agency_id = $${params.length}`);
    }
    // mereu filtrăm doar agenții activi
    clauses.push(`active = true`);
    clauses.push(`role = 'agent'`);

    const sql = `
      SELECT *
        FROM employees
       WHERE ${clauses.join(' AND ')}
       ORDER BY name ASC
    `;

    const { rows } = await db.query(sql, params);
    res.json(rows);

  } catch (err) {
    console.error('GET employees error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});




// CREATE
router.post('/', async (req, res) => {
  const { name, phone = null, email = null, role, operator_id } = req.body;
  if (!name) return res.status(400).json({ error: 'Name is required' });
  try {
    const result = await db.query(
      `INSERT INTO employees (name, phone, email, role, operator_id, active)
       VALUES ($1,$2,$3,$4,$5, true)
       RETURNING *`,
      [name, phone, email, role, operator_id]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') { // unique_violation
      return res.status(409).json({ error: 'Phone or email must be unique' });
    } else if (err.code === '23503') {
      return res.status(400).json({ error: 'Invalid operator_id' });
    }
    console.error('CREATE employee error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// UPDATE
router.put('/:id', async (req, res) => {
  const { id } = req.params;
  const { name, phone = null, email = null, role, operator_id, active } = req.body;
  if (!name) return res.status(400).json({ error: 'Name is required' });
  try {
    const result = await db.query(
      `UPDATE employees
       SET name=$1, phone=$2, email=$3, role=$4, operator_id=$5, active=$6
       WHERE id=$7
       RETURNING *`,
      [name, phone, email, role, operator_id, active, id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Not found' });
    res.json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Phone or email must be unique' });
    }
    console.error('UPDATE employee error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// PARTIAL UPDATE (toggle active)
router.patch('/:id', async (req, res) => {
  const { id } = req.params;
  const { active } = req.body;
  try {
    const result = await db.query(
      `UPDATE employees
        SET active = $1
        WHERE id = $2
        RETURNING *`,
      [active, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error('PATCH employee error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// DELETE → “soft‐delete” to avoid FK errors
router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    // mark inactive instead of actual delete
    const result = await db.query(
      `UPDATE employees
       SET active = false
       WHERE id = $1
       RETURNING *`,
      [id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    console.error('DELETE employee error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
