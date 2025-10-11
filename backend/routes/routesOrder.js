const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /api/routes_order?operator_id=1 sau /api/routes_order
router.get('/', async (req, res) => {
  const { operator_id } = req.query;
  try {
    let turRes, returRes;

    if (operator_id) {
      // Pentru un operator anume, exact ca înainte
      turRes = await db.query(`
        SELECT r.name, r.order_index
        FROM route_schedules rs
        JOIN routes r ON r.id = rs.route_id
        WHERE rs.operator_id = $1 AND rs.direction = 'tur'
        GROUP BY r.name, r.order_index
        ORDER BY r.order_index
      `, [operator_id]);

      returRes = await db.query(`
        SELECT r.name, r.order_index
        FROM route_schedules rs
        JOIN routes r ON r.id = rs.route_id
        WHERE rs.operator_id = $1 AND rs.direction = 'retur'
        GROUP BY r.name, r.order_index
        ORDER BY r.order_index
      `, [operator_id]);
    } else {
      // Fără operator_id: toate rutele distincte, ordonate global
turRes = await db.query(`
  SELECT DISTINCT r.name, r.order_index
  FROM route_schedules rs
  JOIN routes r ON r.id = rs.route_id
  WHERE rs.direction = 'tur'
  ORDER BY r.order_index
`);

returRes = await db.query(`
  SELECT DISTINCT r.name, r.order_ind
  ex
  FROM route_schedules rs
  JOIN routes r ON r.id = rs.route_id
  WHERE rs.direction = 'retur'
  ORDER BY r.order_index
`);
    }

    res.json({
      tur: turRes.rows.map(r => r.name),
      retur: returRes.rows.map(r => r.name)
    });

  } catch (err) {
    console.error('GET /api/routes_order error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
