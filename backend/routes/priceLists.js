// File: backend/routes/priceLists.js

const express = require('express');
const router = express.Router();
const pool = require('../db');

/**
 * GET /api/price-lists
 * - Optional query params: route, category, date
 * - Returns all lists if no filters,
 *   or lists matching route+category up to given date.
 */
router.get('/price-lists', async (req, res) => {
  const { route, category, date } = req.query;

  try {
    if (route && category && date) {
      const sql = `
        SELECT id, name, version, effective_from
          FROM price_lists
         WHERE route_id    = $1
           AND category_id = $2
           AND effective_from::date <= $3::date
         ORDER BY effective_from DESC
      `;
      const { rows } = await pool.query(sql, [route, category, date]);
      return res.json(rows);
    }

    // No filters: return all
    const sqlAll = `
      SELECT id, name, version, effective_from,
             route_id, category_id, created_by, created_at
        FROM price_lists
       ORDER BY effective_from DESC
    `;
    const { rows } = await pool.query(sqlAll);
    return res.json(rows);

  } catch (error) {
    console.error('[GET /api/price-lists]', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/pricing-categories
 * Returns active pricing categories
 */
router.get('/pricing-categories', async (req, res) => {
  try {
    const sql = `
      SELECT id, name
        FROM pricing_categories
       WHERE active
       ORDER BY id
    `;
    const { rows } = await pool.query(sql);
    return res.json(rows);

  } catch (error) {
    console.error('[GET /api/pricing-categories]', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/price-lists/:id/items
 * Returns all items for a specific price list
 */
router.get('/price-lists/:id/items', async (req, res) => {
  const listId = Number(req.params.id);
  try {
    // determinăm route_id (pt. filtrări/afișări dacă ai nevoie în viitor)
    const { rows: rrows } = await pool.query(
      'SELECT route_id FROM price_lists WHERE id = $1',
      [listId]
    );
    const routeId = rrows?.[0]?.route_id ?? null;

const sql = `
  SELECT
    pli.id,
    pli.price_list_id,
    pl.route_id,                -- ← luăm route_id din price_lists
    pli.from_station_id,
    s1.name AS from_stop,
    pli.to_station_id,
    s2.name AS to_stop,
    pli.price,
    pli.price_return
  FROM price_list_items pli
  JOIN price_lists pl ON pl.id = pli.price_list_id   -- ← JOIN ca să avem route_id
  LEFT JOIN stations s1 ON s1.id = pli.from_station_id
  LEFT JOIN stations s2 ON s2.id = pli.to_station_id
  WHERE pli.price_list_id = $1
  ORDER BY COALESCE(pl.route_id, $2) NULLS LAST, s1.name NULLS LAST, s2.name NULLS LAST, pli.id;
`;
const { rows } = await pool.query(sql, [listId, routeId]);
return res.json(rows);
  } catch (error) {
    console.error('[GET /api/price-lists/:id/items]', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});


/**
 * POST /api/price-lists
 * Create or overwrite a price list for a route+category+date
 * Body: { route, category, effective_from, name, version, items[], created_by }
 */
router.post('/price-lists', async (req, res) => {
  const { route, category, effective_from, name, version, items, created_by } = req.body;

  if (!route || !category || !created_by) {
    return res.status(400).json({ error: 'route, category, and created_by are required' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Check existing list
    const checkSql = `
      SELECT id
        FROM price_lists
       WHERE route_id       = $1
         AND category_id    = $2
         AND effective_from = $3
       LIMIT 1
    `;
    const { rows: existRows } = await client.query(checkSql, [route, category, effective_from]);

    let listId;
    if (existRows.length) {
      // Overwrite existing
      listId = existRows[0].id;
      const updateSql = `
        UPDATE price_lists
           SET name = $1, version = $2
         WHERE id = $3
      `;
      await client.query(updateSql, [name, version, listId]);
      await client.query(`DELETE FROM price_list_items WHERE price_list_id = $1`, [listId]);
    } else {
      // Create new list
      const insertSql = `
        INSERT INTO price_lists
          (name, version, effective_from, route_id, category_id, created_by)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id
      `;
      const { rows } = await client.query(insertSql, [
        name, version, effective_from, route, category, created_by
      ]);
      listId = rows[0].id;
    }

    
    // Insert items (support IDs or names)
    const mapStationsForRoute = async (routeId) => {
      const { rows } = await client.query(`
        SELECT s.id AS station_id, s.name
          FROM route_stations rs
          JOIN stations s ON s.id = rs.station_id
         WHERE rs.route_id = $1
      `, [routeId]);
      const map = new Map();
      rows.forEach(r => map.set(r.name, r.station_id));
      return map;
    };
    const nameToId = await mapStationsForRoute(route);

const itemSql = `
  INSERT INTO price_list_items
    (price_list_id, from_station_id, to_station_id, price, price_return)
  VALUES ($1, $2, $3, $4, $5)
`;
for (const it of items) {
  const from_stop = it.from_stop ?? null;
  const to_stop   = it.to_stop ?? null;
  const from_station_id = it.from_station_id ?? (from_stop ? nameToId.get(from_stop) : null) ?? null;
  const to_station_id   = it.to_station_id   ?? (to_stop   ? nameToId.get(to_stop)   : null) ?? null;
  await client.query(itemSql, [
    listId,
    from_station_id,
    to_station_id,
    it.price,
    it.price_return ?? null
  ]);
}

    await client.query('COMMIT');
    return res.json({ id: listId });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('[POST /api/price-lists]', error);
    return res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
});

/**
 * PUT /api/price-lists/:id
 * Update metadata and items for an existing list
 * Body: { effective_from, name, version, items[] }
 */
router.put('/price-lists/:id', async (req, res) => {
  const listId = req.params.id;
  const { effective_from, name, version, items } = req.body;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const updateSql = `
      UPDATE price_lists
         SET name = $1, version = $2, effective_from = $3
       WHERE id = $4
    `;
    await client.query(updateSql, [name, version, effective_from, listId]);
    
await client.query(`DELETE FROM price_list_items WHERE price_list_id = $1`, [listId]);

// Upsert items supporting IDs or names (compat mode)
const mapStationsForRoute = async (routeId) => {
  const { rows } = await client.query(`
    SELECT s.id AS station_id, s.name
      FROM route_stations rs
      JOIN stations s ON s.id = rs.station_id
     WHERE rs.route_id = $1
  `, [routeId]);
  const map = new Map();
  rows.forEach(r => map.set(r.name, r.station_id));
  return map;
};

const { rows: rid } = await client.query(`SELECT route_id FROM price_lists WHERE id = $1`, [listId]);
const routeId = rid?.[0]?.route_id;
const nameToId = routeId ? await mapStationsForRoute(routeId) : new Map();

const itemSql = `
  INSERT INTO price_list_items
    (price_list_id, from_station_id, to_station_id, price, price_return)
  VALUES ($1, $2, $3, $4, $5)
`;
for (const it of items) {
  const from_stop = it.from_stop ?? null;
  const to_stop   = it.to_stop ?? null;
  const from_station_id = it.from_station_id ?? (from_stop ? nameToId.get(from_stop) : null) ?? null;
  const to_station_id   = it.to_station_id   ?? (to_stop   ? nameToId.get(to_stop)   : null) ?? null;
  await client.query(itemSql, [
    listId,
    from_station_id,
    to_station_id,
    it.price,
    it.price_return ?? null
  ]);
}


    await client.query('COMMIT');
    return res.sendStatus(204);

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('[PUT /api/price-lists/:id]', error);
    return res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
});

/**
 * DELETE /api/price-lists/:id
 * Remove a price list and its items
 */
router.delete('/price-lists/:id', async (req, res) => {
  const listId = req.params.id;
  try {
    await pool.query(`DELETE FROM price_list_items WHERE price_list_id = $1`, [listId]);
    await pool.query(`DELETE FROM price_lists       WHERE id = $1`, [listId]);
    return res.sendStatus(204);
  } catch (error) {
    console.error('[DELETE /api/price-lists/:id]', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});




/**
 * POST /api/price-lists/:id/copy-opposite
 * Copy a price list (route/category/date) to its opposite route.
 */
router.post('/price-lists/:id/copy-opposite', async (req, res) => {
  const srcId = req.params.id;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // 1. Preia metadatele listei sursă
    const srcRes = await client.query(
      `SELECT route_id, category_id, effective_from, name, version, created_by
         FROM price_lists WHERE id = $1`,
      [srcId]
    );
    if (!srcRes.rows.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Source list not found' });
    }
    const { route_id: srcRoute, category_id, effective_from, name, version, created_by } = srcRes.rows[0];

    // 2. Află ruta opusă
    const oppRes = await client.query(
      `SELECT opposite_route_id FROM routes WHERE id = $1`,
      [srcRoute]
    );
    const oppRoute = oppRes.rows[0]?.opposite_route_id;
    if (!oppRoute) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'No opposite route defined' });
    }

    // 3. Verifică dacă există deja o listă pentru ruta opusă la aceeași dată și categorie
    const existRes = await client.query(
      `SELECT id FROM price_lists
         WHERE route_id = $1
           AND category_id = $2
           AND effective_from = $3
         LIMIT 1`,
      [oppRoute, category_id, effective_from]
    );
    let newListId;
    if (existRes.rows.length) {
      // 3a. Overwrite
      newListId = existRes.rows[0].id;
      await client.query(
        `UPDATE price_lists
           SET name = $1, version = $2
         WHERE id = $3`,
        [name, version, newListId]
      );
      await client.query(
        `DELETE FROM price_list_items WHERE price_list_id = $1`,
        [newListId]
      );
    } else {
      // 3b. Create new
      const ins = await client.query(
        `INSERT INTO price_lists
           (name, version, effective_from, route_id, category_id, created_by)
         VALUES ($1,$2,$3,$4,$5,$6)
         RETURNING id`,
        [name, version, effective_from, oppRoute, category_id, created_by]
      );
      newListId = ins.rows[0].id;
    }

// luăm itemele existente (fără route_id)
const itemsRes = await client.query(
  `SELECT from_station_id, to_station_id, price, price_return
     FROM price_list_items
    WHERE price_list_id = $1`,
  [srcId]
);

// inserăm în lista nouă inversând capetele
for (const { from_station_id, to_station_id, price, price_return } of itemsRes.rows) {
  await client.query(
    `INSERT INTO price_list_items
       (price_list_id, from_station_id, to_station_id, price, price_return)
     VALUES ($1, $2, $3, $4, $5)`,
    [newListId, to_station_id, from_station_id, price, price_return]
  );
}

    await client.query('COMMIT');
    return res.json({ id: newListId });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('[POST /api/price-lists/:id/copy-opposite]', error);
    return res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
});








module.exports = router;
