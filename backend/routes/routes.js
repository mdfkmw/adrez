// backend/routes/routes.js
const express = require('express');
const router  = express.Router();
const db      = require('../db');          // pg-pool

/*────────────────────────────── 1.  LISTĂ RUTE ──────────────────────────────
   GET /api/routes?date=YYYY-MM-DD[&operator_id=ID]                           */
router.get('/', async (req, res) => {
  const dateStr    = req.query.date ?? new Date().toISOString().slice(0, 10);
  const operatorId = req.query.operator_id ?? null;

  /* parametri & JOIN în funcție de operator */
  const params = [dateStr];
  const joinSchedules = operatorId
    ? (params.push(operatorId),
       `JOIN  route_schedules rs ON rs.route_id = r.id AND rs.operator_id = $2`)
    : `LEFT JOIN route_schedules rs ON rs.route_id = r.id`;

  const sql = `
    SELECT
      r.id,
      r.name,
      r.stops,
      r.direction,
      r.opposite_route_id,

      /* programele (plecările) din ziua cerută */
      COALESCE(
        JSON_AGG(
          JSON_BUILD_OBJECT(
            'scheduleId',     rs.id,
            'departure',      TO_CHAR(rs.departure,'HH24:MI'),
            'operatorId',     rs.operator_id,
            'themeColor',     op.theme_color,
            'disabledRun',    COALESCE(se.disable_run,    false),
            'disabledOnline', COALESCE(se.disable_online, false),
            'tripDisabled',   COALESCE(t.disabled,        false)
          )
          ORDER BY rs.departure
        ) FILTER (WHERE rs.id IS NOT NULL),
        '[]'
      ) AS schedules
    FROM routes r
    ${joinSchedules}
    LEFT JOIN operators           op ON op.id               = rs.operator_id
    LEFT JOIN schedule_exceptions se ON se.schedule_id      = rs.id
         AND ( se.exception_date  = $1
            OR se.weekday         = EXTRACT(DOW FROM $1)::smallint )
    LEFT JOIN trips               t  ON t.route_schedule_id = rs.id
         AND t.date               = $1
    GROUP BY r.id, r.name, r.stops, r.direction, r.opposite_route_id
    ORDER BY r.name;
  `;

  try {
    const { rows } = await db.query(sql, params);
    res.json(rows);
  } catch (err) {
    console.error('GET /api/routes', err);
    res.status(500).json({ error: 'Eroare internă' });
  }
});

/*──────────────────────── 2.  STAȚIILE UNEI RUTE ────────────────────────────
   GET /api/routes/:id/stations                                                */
router.get('/:id/stations', async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT
         rs.id,
         rs.sequence,
         s.id          AS station_id,
         s.name,
         s.latitude,
         s.longitude,
         rs.geofence_type,
         rs.geofence_radius_m,
         ST_AsGeoJSON(rs.geofence_polygon)::json AS geofence_polygon,
         rs.distance_from_previous_km         AS distance_km,
         rs.travel_time_from_previous_minutes AS duration_min
       FROM route_stations rs
       JOIN stations s ON s.id = rs.station_id
       WHERE rs.route_id = $1
       ORDER BY rs.sequence`,
      [req.params.id]
    );
    res.json(rows);
  } catch (err) { next(err); }
});

/*────────────────────── 3.  RESCRIE LISTA STAȚIILOR ────────────────────────
   PUT /api/routes/:id/stations  (array de stații)                             */
router.put('/:id/stations', async (req, res, next) => {
  const routeId = req.params.id;
  const stops   = req.body;

  try {
    await db.query('BEGIN');
    await db.query('DELETE FROM route_stations WHERE route_id = $1', [routeId]);

    for (const s of stops) {
      const type   = ['circle','polygon'].includes(s.geofence_type) ? s.geofence_type : 'circle';
      const radius = type === 'circle' ? (s.geofence_radius_m || 200) : null;
      const poly   = type === 'polygon' && s.geofence_polygon?.length
        ? JSON.stringify({
            type: 'Polygon',
            coordinates: [s.geofence_polygon.map(p => [p.lng, p.lat])]
          })
        : null;

      await db.query(
        `INSERT INTO route_stations
           (route_id, station_id, sequence,
            distance_from_previous_km, travel_time_from_previous_minutes,
            geofence_type, geofence_radius_m, geofence_polygon)
         VALUES ($1,$2,$3,$4,$5,$6,$7,
           CASE WHEN $6 = 'polygon'
                THEN ST_SetSRID(ST_GeomFromGeoJSON($8),4326)
                ELSE NULL END)`,
        [
          routeId,
          s.station_id,
          s.sequence,
          s.distance_km  ?? null,
          s.duration_min ?? null,
          type,
          radius,
          poly
        ]
      );
    }

    await db.query('COMMIT');
    res.sendStatus(204);
  } catch (err) {
    await db.query('ROLLBACK');
    next(err);
  }
});

/*──────────────────── 4.  ȘTERGE O STAȚIE DIN TRASEU ────────────────────────
   DELETE /api/route-stations/:id                                              */
router.delete('/route-stations/:id', async (req, res, next) => {
  try {
    await db.query('DELETE FROM route_stations WHERE id = $1', [req.params.id]);
    res.sendStatus(204);
  } catch (err) { next(err); }
});

/*──────────────────────────── 5.  GET PREȚ SEGMENT ──────────────────────────
   GET /api/routes/price?route_id=&from_station_id=&to_station_id=&category=&date= */
router.get('/price', async (req, res) => {
  const { route_id, from_station_id, to_station_id, category, date } = req.query;

  const rId    = Number(route_id);
  const fromId = Number(from_station_id);
  const toId   = Number(to_station_id);
  const catId  = Number(category);

  if (!rId || !fromId || !toId || !catId || !date) {
    return res.status(400).json({ error: 'params missing' });
  }

  const sql = `
    SELECT
      pli.price,
      pl.id          AS price_list_id,
      pl.category_id AS pricing_category_id
    FROM price_list_items pli
    JOIN price_lists      pl ON pl.id = pli.price_list_id
    WHERE pl.route_id = $1
      AND pli.from_station_id = $2
      AND pli.to_station_id   = $3
      AND pl.category_id      = $4
      AND pl.effective_from = (
            SELECT MAX(effective_from)
              FROM price_lists
             WHERE route_id       = $1
               AND effective_from <= $5
      )
    LIMIT 1
  `;
  const params = [rId, fromId, toId, catId, date];

  try {
    const { rows } = await db.query(sql, params);
    if (!rows.length) return res.status(404).json({ error: 'Preț inexistent' });

    res.json({
      price: rows[0].price,
      price_list_id: rows[0].price_list_id,
      pricing_category_id: rows[0].pricing_category_id
    });
  } catch (err) {
    console.error('GET /api/routes/price', err);
    res.status(500).json({ error: 'Eroare internă' });
  }
});


/*──────────────────── 6.  RUTE MOȘTENITE DIN CODUL VECHI ────────────────────
   GET /api/routes/:id/stops   &   PUT /api/routes/:id/stops                  */

router.get('/:id/stops', async (req, res) => {
  const { rows } = await db.query('SELECT stops FROM routes WHERE id = $1', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Ruta nu a fost găsită' });
  res.json({ stops: rows[0].stops });
});

router.put('/:id/stops', async (req, res) => {
  const { name, stops, hours, agency_id } = req.body;
  const fields = [];
  const values = [];
  let idx = 1;

  if (name      !== undefined) { fields.push(`name = $${idx++}`);      values.push(name); }
  if (stops     !== undefined) { fields.push(`stops = $${idx++}`);     values.push(stops); }
  if (hours     !== undefined) { fields.push(`hours = $${idx++}`);     values.push(hours); }
  if (agency_id !== undefined) { fields.push(`agency_id = $${idx++}`); values.push(agency_id); }

  if (!fields.length) return res.status(400).json({ error: 'Nimic de actualizat' });

  values.push(req.params.id);
  const sql = `UPDATE routes SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`;

  try {
    const { rows } = await db.query(sql, values);
    if (!rows.length) return res.status(404).json({ error: 'Ruta nu a fost găsită' });
    res.json(rows[0]);
  } catch (err) {
    console.error('PUT /api/routes/:id/stops', err);
    res.status(500).json({ error: 'Eroare internă' });
  }
});

/*────────────────────────────────────────────────────────────────────────────*/
module.exports = router;
