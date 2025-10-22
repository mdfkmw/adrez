const express = require('express');
const db = require('../db');
const router = express.Router();

const { requireAuth, requireRole } = require('../middleware/auth');

+// ✅ Acces: toți utilizatorii autentificați (agent/driver pot CITI; write doar admin/op_admin)
router.use(requireAuth);

// ✅ Pentru operator_admin: impunem operator_id-ul propriu în query/body
router.use((req, _res, next) => {
  if (req.user?.role === 'operator_admin') {
    const opId = String(req.user.operator_id || '');
    // Forțăm operator_id în query (listări/filtrări)
    if (req.query && typeof req.query === 'object') {
      req.query.operator_id = opId;
    }
    // Forțăm operator_id în body (create/update)
    if (req.body && typeof req.body === 'object') {
      req.body.operator_id = Number(opId);
    }
  }
  next();
});



/**
 * GET /api/routes/:routeId/discounts?time=HH:MM
 * Returnează lista de tipuri de discount (id, code, label, value_off, type)
 * valabile pentru combinația routeId + time
 */
router.get('/routes/:routeId/discounts', requireRole('admin','operator_admin','agent','driver'), async (req, res) => {
  const { routeId } = req.params;
  let { time } = req.query;

  // normalizăm ora: '06:00:00' -> '06:00'
  if (time && time.length === 8) time = time.slice(0, 5);

  try {
    const { rows } = await db.query(
      `
      SELECT
        dt.id,
        dt.code,
        dt.label,
        dt.value_off AS discount_value,
        dt.type      AS discount_type
      FROM route_schedule_discounts rsd
      JOIN discount_types dt ON dt.id = rsd.discount_type_id
      JOIN route_schedules rs ON rs.id = rsd.route_schedule_id
      WHERE rs.route_id = ?
        AND TIME_FORMAT(rs.departure, '%H:%i') = ?
      ORDER BY dt.label
      `,
      [routeId, time]
    );

    res.json(rows);
  } catch (err) {
    console.error('GET /api/routes/:routeId/discounts error:', err);
    res.status(500).json({ error: 'Eroare la extragerea reducerilor' });
  }
});

/**
 * PUT /api/routes/:routeId/discounts
 * Body: { time: 'HH:MM', discountTypeIds: [1,3,5] }
 * Actualizează setul de discount-uri aplicabile pentru routeId + time.
 */
router.put('/routes/:routeId/discounts', requireRole('admin','operator_admin'), async (req, res) => {
  const { routeId } = req.params;
  const { time, discountTypeIds } = req.body;

  if (!time || !Array.isArray(discountTypeIds)) {
    return res.status(400).json({ error: 'Trebuie să trimiți time și discountTypeIds ca array' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // 🔹 Șterge asocierile vechi pentru ruta + ora respectivă
    await conn.execute(
      `
      DELETE rsd FROM route_schedule_discounts rsd
      JOIN route_schedules rs ON rs.id = rsd.route_schedule_id
      WHERE rs.route_id = ?
        AND TIME_FORMAT(rs.departure, '%H:%i') = ?
      `,
      [routeId, time]
    );

    // 🔹 Găsim id-ul route_schedule-ului pentru ruta + ora dată
    const [sched] = await conn.execute(
      `SELECT id FROM route_schedules WHERE route_id = ? AND TIME_FORMAT(departure, '%H:%i') = ? LIMIT 1`,
      [routeId, time]
    );

    if (sched.length) {
      const rsId = sched[0].id;

      for (const dtId of discountTypeIds) {
        // evităm duplicatele: verificăm înainte de insert
        await conn.execute(
          `INSERT IGNORE INTO route_schedule_discounts (route_schedule_id, discount_type_id)
           VALUES (?, ?)`,
          [rsId, dtId]
        );
      }
    }

    await conn.commit();
    conn.release();
    res.sendStatus(204);
  } catch (err) {
    await conn.rollback();
    conn.release();
    console.error('PUT /api/routes/:routeId/discounts error:', err);
    res.status(500).json({ error: 'Eroare la salvarea reducerilor pentru route+time' });
  }
});

module.exports = router;
