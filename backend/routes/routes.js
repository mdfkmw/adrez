// backend/routes/routes.js — MariaDB 10.6
const express = require('express');
const router = express.Router();
const db = require('../db');
const { requireAuth, requireRole } = require('../middleware/auth');

// ✅ Acces: admin, operator_admin, agent
router.use(requireAuth, requireRole('admin', 'operator_admin', 'agent'));

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



console.log('[ROUTER LOADED] routes/routes.js');

/*────────────────────────────── 1) LISTĂ RUTE ──────────────────────────────
  GET /api/routes?date=YYYY-MM-DD[&operator_id=ID]
  Notă: în PG foloseai JSON_AGG + FILTER. În MariaDB agregăm în JS pentru stabilitate. */
router.get('/', async (req, res) => {
  // normalizăm data la 'YYYY-MM-DD'
  const dateStr = (req.query.date && String(req.query.date).slice(0, 10)) || new Date().toISOString().slice(0, 10);
  const operatorId = req.query.operator_id ?? null;

  // JOIN condiționat după operator (ca în PG)
  const joinSchedules = operatorId
    ? `JOIN  route_schedules rs ON rs.route_id = r.id AND rs.operator_id = ?`
    : `LEFT JOIN route_schedules rs ON rs.route_id = r.id`;

  const sql = `
  SELECT
    r.id    AS r_id,
    r.name  AS r_name,
    r.direction,
    r.opposite_route_id,

    rs.id   AS schedule_id,
    TIME_FORMAT(rs.departure, '%H:%i') AS departure,
    rs.operator_id,
    op.theme_color,

    /* disabled_run dacă există vreo regulă ce oprește cursa în ziua respectivă
       (permanentă, pe weekday sau pe data exactă) */
    EXISTS (
      SELECT 1
        FROM schedule_exceptions se
       WHERE se.schedule_id = rs.id
         AND se.disable_run = 1
         AND (
               se.exception_date IS NULL
            OR se.exception_date = DATE(?)
            OR se.weekday = DAYOFWEEK(DATE(?)) - 1
        )
    ) AS disabled_run,

    /* disabled_online după aceeași logică */
    EXISTS (
      SELECT 1
        FROM schedule_exceptions se
       WHERE se.schedule_id = rs.id
         AND se.disable_online = 1
         AND (
               se.exception_date IS NULL
            OR se.exception_date = DATE(?)
            OR se.weekday = DAYOFWEEK(DATE(?)) - 1
        )
    ) AS disabled_online,

    t.disabled AS trip_disabled
  FROM routes r
  ${joinSchedules}
  LEFT JOIN operators op ON op.id = rs.operator_id
  LEFT JOIN trips t ON t.route_schedule_id = rs.id AND t.date = DATE(?)
  ORDER BY r.name, rs.departure
  `;
  try {
    // parametri în ordinea apariției în SQL
    // dacă ai operatorId, e primul parametru; apoi 4x dateStr pentru EXISTS + 1x pentru LEFT JOIN trips
    const execParams = operatorId
      ? [operatorId, dateStr, dateStr, dateStr, dateStr, dateStr]
      : [dateStr, dateStr, dateStr, dateStr, dateStr];
    const { rows } = await db.query(sql, execParams);

    // Agregăm în JS într-o structură {id,name,stops,direction,opposite_route_id,schedules:[]}
    const byRoute = new Map();
  for (const r of rows) {
    if (!byRoute.has(r.r_id)) {
      byRoute.set(r.r_id, {
        id: r.r_id,
        name: r.r_name,
        direction: r.direction,
        opposite_route_id: r.opposite_route_id,
        schedules: []
      });
    }

    if (r.schedule_id) {
      const routeObj = byRoute.get(r.r_id);

      // verificăm dacă am mai văzut acest schedule_id (poate există mai multe rânduri din cauza exceptions)
      let sched = routeObj.schedules.find(s => s.scheduleId === r.schedule_id);
      if (!sched) {
        sched = {
          scheduleId: r.schedule_id,
          departure: r.departure,
          operatorId: r.operator_id,
          themeColor: r.theme_color,
          disabledRun: !!r.disabled_run,
          disabledOnline: !!r.disabled_online,
          tripDisabled: !!r.trip_disabled
        };
        routeObj.schedules.push(sched);
      } else {
        // agregăm flag-urile (OR)
        sched.disabledRun = sched.disabledRun || !!r.disabled_run;
        sched.disabledOnline = sched.disabledOnline || !!r.disabled_online;
        sched.tripDisabled = sched.tripDisabled || !!r.trip_disabled;
      }
    }
  }

    // sortăm programările pe oră (safety) și pregătim lista finală
    const out = Array.from(byRoute.values()).map(rt => {
      rt.schedules.sort((a, b) => (a.departure || '').localeCompare(b.departure || ''));
      return rt;
    });
    // Dacă nu există rânduri deloc (fără join), tot vrem să trimitem toate rutele
    if (rows.length === 0) {
      const { rows: routesOnly } = await db.query(
        `SELECT id, name, direction, opposite_route_id FROM routes ORDER BY name`
      );
      return res.json(routesOnly.map(r => ({
        id: r.id, name: r.name, direction: r.direction,
        opposite_route_id: r.opposite_route_id, schedules: []
      })));
    }

  res.json(out);
} catch (err) {
  console.error('GET /api/routes', err);
  res.status(500).json({ error: 'Eroare internă' });
}
});

/*──────────────────────── 2) STAȚIILE UNEI RUTE ────────────────────────────
  GET /api/routes/:id/stations
  Notă: în PG foloseai ST_AsGeoJSON(... )::json; aici returnăm geofence_polygon ca JSON/text. */
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
         ST_AsText(rs.geofence_polygon) AS geofence_polygon,
         rs.distance_from_previous_km    AS distance_km,
         rs.travel_time_from_previous_minutes AS duration_min
       FROM route_stations rs
       JOIN stations s ON s.id = rs.station_id
       WHERE rs.route_id = ?
       ORDER BY rs.sequence`,
      [req.params.id]
    );

    // dacă geofence_polygon e text JSON, nu-l mai parsez aici; frontend-ul îl poate folosi direct
    res.json(rows);
  } catch (err) { next(err); }
});

/*────────────────────── 3) RESCRIE LISTA STAȚIILOR ────────────────────────
  PUT /api/routes/:id/stations (array de stații)
  Notă: în PG construiai geometrii. În MariaDB salvăm JSON-ul polygon ca TEXT/JSON nativ. */
router.put('/:id/stations', async (req, res, next) => {
  const routeId = req.params.id;
  const stops = req.body;

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    await conn.execute('DELETE FROM route_stations WHERE route_id = ?', [routeId]);

    for (const s of stops) {
      const type = ['circle', 'polygon'].includes(s.geofence_type) ? s.geofence_type : 'circle';
      const radius = type === 'circle' ? (s.geofence_radius_m || 200) : null;
      // Acceptăm: 1) array [{lat,lng}], 2) WKT "POLYGON(...)", 3) GeoJSON string
      let poly = null;
      if (type === 'polygon') {
        if (Array.isArray(s.geofence_polygon) && s.geofence_polygon.length >= 3) {
          const ring = s.geofence_polygon.map(p => [Number(p.lng), Number(p.lat)]);
          // închidem inelul dacă nu e închis
          const [fLng, fLat] = ring[0], [lLng, lLat] = ring[ring.length - 1];
          if (Math.abs(fLng - lLng) > 1e-9 || Math.abs(fLat - lLat) > 1e-9) ring.push([fLng, fLat]);
          const coords = ring.map(([lng, lat]) => `${lng} ${lat}`).join(', ');
          poly = `POLYGON((${coords}))`;
        } else if (typeof s.geofence_polygon === 'string' && s.geofence_polygon.trim()) {
          poly = s.geofence_polygon.trim(); // WKT sau GeoJSON
        }
      }
      // pregătim SQL în funcție de tipul stringului 'poly'
      let polySql = 'NULL';
      let polyParam = null;
      if (poly) {
        if (/^POLYGON\s*\(/i.test(poly)) {         // WKT
          polySql = 'ST_GeomFromText(?, 4326)';
          polyParam = poly;
        } else if (/^\s*\{/.test(poly)) {          // GeoJSON text
          polySql = 'ST_GeomFromGeoJSON(?)';
          polyParam = poly;
        }
      }

      const sql = `
        INSERT INTO route_stations
          (route_id, station_id, sequence,
           distance_from_previous_km, travel_time_from_previous_minutes,
           geofence_type, geofence_radius_m, geofence_polygon)
        VALUES (?, ?, ?, ?, ?, ?, ?, ${polySql})
      `;
      const params = [
        routeId,
        s.station_id,
        s.sequence,
        s.distance_km ?? null,
        s.duration_min ?? null,
        type,
        radius
      ];
      if (polyParam) params.push(polyParam);
      await conn.execute(sql, params);
    }

    await conn.commit();
    conn.release();
    res.sendStatus(204);
  } catch (err) {
    await conn.rollback();
    conn.release();
    next(err);
  }
});

/*──────────────────── 4) ȘTERGE O STAȚIE DIN TRASEU ────────────────────────
  DELETE /api/route-stations/:id */
router.delete('/route-stations/:id', async (req, res, next) => {
  try {
    await db.query('DELETE FROM route_stations WHERE id = ?', [req.params.id]);
    res.sendStatus(204);
  } catch (err) { next(err); }
});

/*──────────────────────────── 5) GET PREȚ SEGMENT ──────────────────────────
  GET /api/routes/price?route_id=&from_station_id=&to_station_id=&category=&date=YYYY-MM-DD */
router.get('/price', async (req, res) => {
  const { route_id, from_station_id, to_station_id, category, date } = req.query;

  const rId = Number(route_id);
  const fromId = Number(from_station_id);
  const toId = Number(to_station_id);
  const catId = Number(category);

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
    WHERE pl.route_id = ?
      AND pli.from_station_id = ?
      AND pli.to_station_id   = ?
      AND pl.category_id      = ?
      AND pl.effective_from = (
            SELECT MAX(effective_from)
              FROM price_lists
             WHERE route_id       = ?
               AND effective_from <= ?
      )
    LIMIT 1
  `;
  const params = [rId, fromId, toId, catId, rId, date];

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

/*──────────────────── 6) RUTE MOȘTENITE DIN CODUL VECHI ────────────────────
  GET /api/routes/:id/stops   &   PUT /api/routes/:id/stops  */

/* GET stops (câmpul JSON/text din routes) */
router.get('/:id/stops', async (req, res) => {
  try {
    const { rows } = await db.query('SELECT stops FROM routes WHERE id = ?', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Ruta nu a fost găsită' });
    res.json({ stops: rows[0].stops });
  } catch (err) {
    console.error('GET /api/routes/:id/stops', err);
    res.status(500).json({ error: 'Eroare internă' });
  }
});

/* PUT stops (și alte câmpuri) — MariaDB nu are RETURNING; citim separat */
router.put('/:id/stops', async (req, res) => {
  const { name, stops, hours, agency_id } = req.body;
  const fields = [];
  const values = [];

  if (name !== undefined) { fields.push(`name = ?`); values.push(name); }
  if (stops !== undefined) { fields.push(`stops = ?`); values.push(stops); }
  if (hours !== undefined) { fields.push(`hours = ?`); values.push(hours); }
  if (agency_id !== undefined) { fields.push(`agency_id = ?`); values.push(agency_id); }

  if (!fields.length) return res.status(400).json({ error: 'Nimic de actualizat' });

  values.push(req.params.id);

  try {
    const upd = await db.query(`UPDATE routes SET ${fields.join(', ')} WHERE id = ?`, values);
    if (upd.rowCount === 0) return res.status(404).json({ error: 'Ruta nu a fost găsită' });

    const { rows } = await db.query('SELECT * FROM routes WHERE id = ?', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Ruta nu a fost găsită' });

    res.json(rows[0]);
  } catch (err) {
    console.error('PUT /api/routes/:id/stops', err);
    res.status(500).json({ error: 'Eroare internă' });
  }
});

module.exports = router;
