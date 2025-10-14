// backend/routes/routesOrder.js — versiune MariaDB
const express = require('express');
const router  = express.Router();
const db      = require('../db');

// GET /api/routes_order?operator_id=1  sau  /api/routes_order
router.get('/', async (req, res) => {
  const { operator_id } = req.query;

  try {
    let turRes, returRes;

    if (operator_id) {
      // 🔹 Pentru un operator anume
      turRes = await db.query(
        `SELECT DISTINCT r.name, r.order_index
           FROM route_schedules rs
           JOIN routes r ON r.id = rs.route_id
          WHERE rs.operator_id = ? AND rs.direction = 'tur'
          ORDER BY r.order_index`,
        [operator_id]
      );

      returRes = await db.query(
        `SELECT DISTINCT r.name, r.order_index
           FROM route_schedules rs
           JOIN routes r ON r.id = rs.route_id
          WHERE rs.operator_id = ? AND rs.direction = 'retur'
          ORDER BY r.order_index`,
        [operator_id]
      );
    } else {
      // 🔹 Fără operator_id: toate rutele distincte
      turRes = await db.query(
        `SELECT DISTINCT r.name, r.order_index
           FROM route_schedules rs
           JOIN routes r ON r.id = rs.route_id
          WHERE rs.direction = 'tur'
          ORDER BY r.order_index`
      );

      returRes = await db.query(
        `SELECT DISTINCT r.name, r.order_index
           FROM route_schedules rs
           JOIN routes r ON r.id = rs.route_id
          WHERE rs.direction = 'retur'
          ORDER BY r.order_index`
      );
    }

    // mysql2/promise => rezultatul are { rows }
    res.json({
      tur: turRes.rows.map(r => r.name),
      retur: returRes.rows.map(r => r.name)
    });

  } catch (err) {
    console.error('GET /api/routes_order error:', err);
    res.status(500).json({ error: 'Eroare internă' });
  }
});

module.exports = router;
