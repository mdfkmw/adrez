const express = require('express');
const router = express.Router();
const db = require('../db');

// 🔹 LIST — cu filtrare după operator / agenție sau toate (admin)
router.get('/', async (req, res) => {
  const { operator_id, agency_id } = req.query;
  try {
    // Caz 1: fără parametri → admin
    if (!operator_id && !agency_id) {
      const result = await db.query('SELECT * FROM employees ORDER BY id ASC');
      return res.json(result.rows);
    }

    // Caz 2: filtrare agent activ
    const clauses = [];
    const params = [];

    if (operator_id) {
      params.push(operator_id);
      clauses.push(`operator_id = ?`);
    }
    if (agency_id) {
      params.push(agency_id);
      clauses.push(`agency_id = ?`);
    }

    clauses.push(`active = 1`);
    clauses.push(`role = 'driver'`);

    const sql = `
      SELECT *
        FROM employees
       WHERE ${clauses.join(' AND ')}
       ORDER BY name ASC
    `;

    const result = await db.query(sql, params);
    res.json(result.rows);
  } catch (err) {
    console.error('GET /employees error:', err);
    res.status(500).json({ error: 'Eroare la interogare DB' });
  }
});

// 🔹 CREATE — adaugă angajat
router.post('/', async (req, res) => {
  const { name, phone = null, email = null, role, operator_id } = req.body;
  if (!name) return res.status(400).json({ error: 'Numele este obligatoriu' });

  try {
    const result = await db.query(
      `INSERT INTO employees (name, phone, email, role, operator_id, active)
       VALUES (?, ?, ?, ?, ?, 1)`,
      [name, phone, email, role, operator_id]
    );

    const inserted = await db.query('SELECT * FROM employees WHERE id = ?', [result.insertId]);
    res.status(201).json(inserted.rows[0]);
  } catch (err) {
    console.error('POST /employees error:', err);

    if (err.errno === 1062) {
      return res.status(409).json({ error: 'Telefonul sau emailul trebuie să fie unice' });
    }
    if (err.errno === 1452) {
      return res.status(400).json({ error: 'operator_id invalid' });
    }

    res.status(500).json({ error: 'Eroare la inserare DB' });
  }
});

// 🔹 UPDATE — actualizează un angajat
router.put('/:id', async (req, res) => {
  const { id } = req.params;
  const { name, phone = null, email = null, role, operator_id, active } = req.body;

  if (!name) return res.status(400).json({ error: 'Numele este obligatoriu' });

  try {
    const result = await db.query(
      `UPDATE employees
          SET name=?, phone=?, email=?, role=?, operator_id=?, active=?
        WHERE id=?`,
      [name, phone, email, role, operator_id, active ? 1 : 0, id]
    );

    if (result.rowCount === 0) return res.status(404).json({ error: 'Angajat inexistent' });

    const updated = await db.query('SELECT * FROM employees WHERE id = ?', [id]);
    res.json(updated.rows[0]);
  } catch (err) {
    console.error('PUT /employees error:', err);

    if (err.errno === 1062) {
      return res.status(409).json({ error: 'Telefonul sau emailul trebuie să fie unice' });
    }

    res.status(500).json({ error: 'Eroare la actualizare DB' });
  }
});

// 🔹 PATCH — active/inactive
router.patch('/:id', async (req, res) => {
  const { id } = req.params;
  const { active } = req.body;

  try {
    const result = await db.query(
      `UPDATE employees
          SET active = ?
        WHERE id = ?`,
      [active ? 1 : 0, id]
    );

    if (result.rowCount === 0) return res.status(404).json({ error: 'Angajat inexistent' });

    const updated = await db.query('SELECT * FROM employees WHERE id = ?', [id]);
    res.json(updated.rows[0]);
  } catch (err) {
    console.error('PATCH /employees error:', err);
    res.status(500).json({ error: 'Eroare la actualizare DB' });
  }
});

// 🔹 DELETE — soft delete (marchează inactiv)
router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await db.query(
      `UPDATE employees SET active = 0 WHERE id = ?`,
      [id]
    );

    if (result.rowCount === 0) return res.status(404).json({ error: 'Angajat inexistent' });

    res.json({ success: true });
  } catch (err) {
    console.error('DELETE /employees error:', err);
    res.status(500).json({ error: 'Eroare la actualizare DB' });
  }
});

module.exports = router;
