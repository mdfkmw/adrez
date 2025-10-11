const express = require('express');
const db = require('../db');
const router = express.Router();

// 1) GET lista tuturor discount-urilor
router.get('/', async (req, res) => {
  const { rows } = await db.query(`SELECT id, code, label, value_off, type FROM discount_types ORDER BY label`);
  res.json(rows);
});

// 2) GET toate schedule‑urilе (route + departure)
router.get('/schedules/all', async (req, res) => {
  const { rows } = await db.query(`
    SELECT rs.id, r.name AS route_name, rs.departure, rs.direction
      FROM route_schedules rs
      JOIN routes r ON r.id = rs.route_id
     ORDER BY r.name, rs.departure
  `);
  res.json(rows);
});

// 3) GET schedule‑urile la care se aplică un discount
router.get('/:discountId/schedules', async (req, res) => {
  const { discountId } = req.params;
  const { rows } = await db.query(`
    SELECT route_schedule_id
      FROM route_schedule_discounts
     WHERE discount_type_id = $1
  `, [discountId]);
  res.json(rows.map(r => r.route_schedule_id));
});

// 4) PUT update asocieri
router.put('/:discountId/schedules', async (req, res) => {
  const { discountId } = req.params;
  const { scheduleIds } = req.body;  // array de INT
  const client = await db.connect();
  try {
    await client.query('BEGIN');
    await client.query(`DELETE FROM route_schedule_discounts WHERE discount_type_id = $1`, [discountId]);
    for (const rsId of scheduleIds) {
      await client.query(`
        INSERT INTO route_schedule_discounts(discount_type_id, route_schedule_id)
        VALUES($1,$2)
      `, [discountId, rsId]);
    }
    await client.query('COMMIT');
    res.sendStatus(204);
  } catch(e) {
    await client.query('ROLLBACK');
    console.error(e);
    res.status(500).json({ error: 'Nu am putut salva asocierile' });
  } finally {
    client.release();
  }
});

router.post('/', async (req, res) => {
  const { code, label, value_off, type } = req.body;
  try {
    const { rows } = await db.query(
      `INSERT INTO discount_types (code, label, value_off, type) VALUES ($1, $2, $3, $4) RETURNING *`,
      [code, label, value_off, type]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error inserting discount type:', err);
    res.status(500).json({ error: 'Database error' });
  }
});


// 5) PUT actualizare discount existent
router.put('/:id', async (req, res) => {
  const { id } = req.params;
  const { code, label, value_off, type } = req.body;

  try {
    const { rowCount } = await db.query(
      `UPDATE discount_types
       SET code = $1, label = $2, value_off = $3, type = $4
       WHERE id = $5`,
      [code, label, value_off, type, id]
    );

    if (rowCount === 0) {
      return res.status(404).json({ error: 'Discount inexistent' });
    }

    res.sendStatus(204);
  } catch (err) {
    console.error('Eroare la actualizarea discountului:', err);
    res.status(500).json({ error: 'Eroare la salvare în DB' });
  }
});




router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await db.query('DELETE FROM discount_types WHERE id = $1', [id]);
    res.sendStatus(204);
  } catch (error) {
    console.error('Eroare la ștergerea tipului de discount:', error);

    // Detectăm eroarea de integritate referențială (cheie externă)
    if (error.code === '23503') {
      return res.status(400).json({
        message: 'Nu poți șterge acest tip de reducere deoarece este folosit într-un traseu.'
      });
    }

    res.status(500).send('Eroare la ștergere');
  }
});




module.exports = router;
