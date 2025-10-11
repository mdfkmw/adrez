// src/routes/routeStations.js
import express from "express";
import pool     from "../db.js";           // wrapper la pg/pool

const router = express.Router();

/**
 * Returnează TUTUROR informațiile de care are nevoie front-end-ul
 * pentru a desena stațiile salvate ale unei rute.
 *
 *   GET /api/routes/:id/stations
 *   răspuns: [
 *     {
 *       sequence: 1,
 *       geofence_type: "circle",
 *       geofence_radius_m: 200,
 *       station_id: 12,
 *       name: "Botoșani",
 *       latitude: 47.7435,
 *       longitude: 26.6699
 *     },
 *     ...
 *   ]
 */
router.get("/:id/stations", async (req, res, next) => {
  try {
    const { rows } = await pool.query(`
      SELECT rs.sequence,
             rs.geofence_type,
             rs.geofence_radius_m,
             s.id          AS station_id,
             s.name,
             s.latitude,
             s.longitude
        FROM route_stations rs
        JOIN stations      s ON s.id = rs.station_id
       WHERE rs.route_id = $1
       ORDER BY rs.sequence
    `, [req.params.id]);

    res.json(rows);
  } catch (err) {
    next(err);
  }
});


router.put("/:id/stations", async (req,res,next) => {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("DELETE FROM route_stations WHERE route_id = $1", [req.params.id]);

    const text = `
      INSERT INTO route_stations
        (route_id, station_id, sequence, geofence_type, geofence_radius_m)
      VALUES ($1,$2,$3,$4,$5)
    `;
    for (const s of req.body) {
      await client.query(text, [
        req.params.id,
        s.station_id,
        s.sequence,
        s.geofence_type,
        s.geofence_radius_m,
      ]);
    }
    await client.query("COMMIT");
    res.sendStatus(204);
  } catch (err) {
    await client.query("ROLLBACK");
    next(err);
  } finally {
    client.release();
  }
});


export default router;
