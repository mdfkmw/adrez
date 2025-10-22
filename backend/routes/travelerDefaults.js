const express = require('express');
const db = require('../db');
const router = express.Router();

const { requireAuth } = require('../middleware/auth');

// ✅ Acces pentru ORICE utilizator AUTENTIFICAT (agent inclus) la GET
router.use(requireAuth);


// Debug scurt: vezi cine e și ce cere (doar în dev)
router.use((req, _res, next) => {
  if (process.env.NODE_ENV !== 'production') {
    console.log('[traveler-defaults] user=', req.user, 'query=', req.query);
  }
  next();
});


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

const sanitizePhone = (raw = '') => raw.replace(/\D/g, '');

router.get('/', async (req, res) => {
  try {
    const phone = sanitizePhone(req.query.phone || '');
    const routeId = Number(req.query.route_id);

    if (!phone || !Number.isInteger(routeId)) {
      return res.json({ found: false });
    }

    const { rows } = await db.query(
      `
        SELECT
          td.id,
          td.board_station_id,
          bs.name AS board_name,
          td.exit_station_id,
          es.name AS exit_name,
          td.use_count,
          td.last_used_at
        FROM traveler_defaults td
        LEFT JOIN stations bs ON bs.id = td.board_station_id
        LEFT JOIN stations es ON es.id = td.exit_station_id
        WHERE td.phone = ? AND td.route_id = ?
        ORDER BY td.last_used_at DESC
        LIMIT 1
      `,
      [phone, routeId],
    );

    if (!rows.length) {
      return res.json({ found: false });
    }

    const row = rows[0];

    return res.json({
      found: true,
      board_station_id: row.board_station_id,
      exit_station_id: row.exit_station_id,
      board_name: row.board_name || null,
      exit_name: row.exit_name || null,
      use_count: row.use_count || 0,
      last_used_at: row.last_used_at || null,
    });
  } catch (err) {
    console.error('[traveler-defaults] error', err);
    return res.status(500).json({ error: 'Eroare la citirea preferințelor de traseu' });
  }
});

module.exports = router;