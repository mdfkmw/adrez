const express = require('express');
const router  = express.Router();
const db      = require('../db');

/*  GET /api/reports/trips
    Params obligatorii:
      operator_id          – id din operators
    Params opționale:
      start (YYYY-MM-DD)   – default = azi
      end   (YYYY-MM-DD)   – default = start
      channel              – online | agent | all (default)
*/
router.get('/trips', async (req, res) => {
  try {
    const {
      operator_id,
      start = new Date().toISOString().slice(0,10),
      end   = start,
      route_id,
      agency_id,
      agent_id,
      hour
    } = req.query;

    const params = [operator_id, start, end];
    const whereExtra = [];
    if (route_id) {
      params.push(route_id);
      whereExtra.push(`AND rs.route_id = $${params.length}`);
    }
    if (agency_id) {
      params.push(agency_id);
      whereExtra.push(`AND e.agency_id = $${params.length}`);
    }
    if (agent_id) {
      params.push(agent_id);
      whereExtra.push(`AND res.created_by = $${params.length}`);
    }
    if (hour) {
      params.push(hour);
      // Filtrare exactă pe ora cursei (coloana trips.time)
      whereExtra.push(`AND t."time" = $${params.length}::time`);
    }
    const extraSql = whereExtra.length ? whereExtra.join('\n        ') : '';

    // 1) trips
    const tripsSql = `
      SELECT
        t.id               AS trip_id,
        t.date             AS trip_date,
        to_char(t.time,'HH24:MI') AS trip_time,
        r.name             AS route_name,
        v.name             AS vehicle_name,
        v.plate_number     AS vehicle_plate,
        v.seat_count       AS seats_total,
        COUNT(res.*)       AS seats_booked,
        COALESCE(SUM(rd.discount_amount),0) AS discount_total,
        COUNT(rd.*)        AS discount_count,
COALESCE(SUM(pay.amount),0) AS net_revenue,

        CASE WHEN rp.booking_channel = 'online' THEN 'online' ELSE 'agent' END AS channel
      FROM trips t
      JOIN route_schedules rs ON rs.id = t.route_schedule_id
      JOIN routes r           ON r.id  = rs.route_id
      JOIN vehicles v ON v.id = t.vehicle_id
      LEFT JOIN reservations res
        ON res.trip_id = t.id
        AND res.status NOT IN ('canceled','cancelled')
      LEFT JOIN reservation_pricing rp
        ON rp.reservation_id = res.id
      LEFT JOIN reservation_discounts rd
        ON rd.reservation_id = res.id
      LEFT JOIN payments pay
        ON pay.reservation_id = res.id
        AND pay.status = 'paid'
     LEFT JOIN employees e
       ON e.id = res.created_by
     LEFT JOIN agencies a
       ON a.id = e.agency_id
      
      WHERE rs.operator_id = $1
        AND t.date BETWEEN $2 AND $3
        ${extraSql}
      GROUP BY
        t.id, t.date, trip_time,
        r.name, v.name, v.plate_number, v.seat_count,
        channel
      ORDER BY trip_time, r.name;
    `;
    const { rows: trips } = await db.query(tripsSql, params);

    // 2) summary
    const summarySql = `
      SELECT
        /* totaluri generale */
        COUNT(res.*) AS total_seats_booked,
        SUM(CASE WHEN res.status IN ('canceled','cancelled') THEN 1 ELSE 0 END) AS total_cancels_noshow,

        /* ACHITATE */
        COUNT(res.*) FILTER (WHERE pay.id IS NOT NULL)      AS paid_seats,
        COALESCE(SUM(pay.amount)        ,0)                 AS paid_total,
        COALESCE(SUM(rd.discount_amount) FILTER (WHERE pay.id IS NOT NULL),0) AS paid_discounts,

        /* DOAR REZERVĂRI (fără payment) */
        COUNT(res.*) FILTER (WHERE pay.id IS NULL)          AS reserved_seats,
        COALESCE(SUM(rp.price_value)    FILTER (WHERE pay.id IS NULL),0)      AS reserved_total,
        COALESCE(SUM(rd.discount_amount) FILTER (WHERE pay.id IS NULL),0)     AS reserved_discounts

      FROM trips t
      JOIN route_schedules rs ON rs.id = t.route_schedule_id
      LEFT JOIN reservations res
        ON res.trip_id = t.id
      LEFT JOIN reservation_pricing rp
        ON rp.reservation_id = res.id
      LEFT JOIN reservation_discounts rd
        ON rd.reservation_id = res.id
      LEFT JOIN payments pay
        ON pay.reservation_id = res.id
        AND pay.status = 'paid'
        
      LEFT JOIN employees e
        ON e.id = res.created_by
      LEFT JOIN agencies a
        ON a.id = e.agency_id
      WHERE rs.operator_id = $1
        AND t.date BETWEEN $2 AND $3
        ${extraSql};
    `;
    const { rows: [summary] } = await db.query(summarySql, params);

    // 3) handover
    const handSql = `
      SELECT
        COALESCE(SUM(p.amount),0) AS to_hand_over
      FROM payments p
      JOIN reservations res
        ON res.id = p.reservation_id
      JOIN trips t
        ON t.id = res.trip_id
      JOIN route_schedules rs
        ON rs.id = t.route_schedule_id
      LEFT JOIN reservation_pricing rp
        ON rp.reservation_id = res.id
      LEFT JOIN employees e
        ON e.id = res.created_by
      LEFT JOIN agencies a
        ON a.id = e.agency_id
      WHERE rs.operator_id = $1
        AND p.status = 'paid'
        AND p.payment_method = 'cash'
        AND p.deposited_at IS NULL
        AND p."timestamp"::date BETWEEN $2 AND $3
        ${extraSql};
    `;
    const { rows: [hand] } = await db.query(handSql, params);

    // 4) discounts by type (achitate vs rezervari)
    const discountsByTypeSql = `
      SELECT
        dt.id    AS discount_type_id,
        dt.label AS discount_label,
        COUNT(rd.*) FILTER (WHERE pay.id IS NOT NULL)                            AS paid_count,
        COALESCE(SUM(rd.discount_amount) FILTER (WHERE pay.id IS NOT NULL), 0)   AS paid_total,
        COUNT(rd.*) FILTER (WHERE pay.id IS NULL)                                AS reserved_count,
        COALESCE(SUM(rd.discount_amount) FILTER (WHERE pay.id IS NULL), 0)       AS reserved_total
      FROM trips t
      JOIN route_schedules rs ON rs.id = t.route_schedule_id
      LEFT JOIN reservations res ON res.trip_id = t.id
      LEFT JOIN reservation_discounts rd ON rd.reservation_id = res.id
      LEFT JOIN discount_types dt ON dt.id = rd.discount_type_id
      LEFT JOIN payments pay ON pay.reservation_id = res.id AND pay.status = 'paid'
      LEFT JOIN employees e ON e.id = res.created_by
      LEFT JOIN agencies a ON a.id = e.agency_id
      WHERE rs.operator_id = $1
        AND t.date BETWEEN $2 AND $3
        ${extraSql}
        AND rd.discount_type_id IS NOT NULL
      GROUP BY dt.id, dt.label
      ORDER BY dt.label;
    `;
    const { rows: discountsByType } = await db.query(discountsByTypeSql, params);

    res.json({ trips, summary, discountsByType, toHandOver: hand.to_hand_over });
  } catch (err) {
    console.error('[GET /api/reports/trips]', err);
    res.status(500).json({ error: 'Eroare internă reports' });
  }
});


// 🔹 Predare totală numerar
router.post('/cash-handover', async (req, res) => {
  const { operator_id, employee_id } = req.body;

  if (!operator_id || !employee_id) {
    return res.status(400).json({ error: 'Lipsește operator_id sau employee_id' });
  }

  try {
    // 1️⃣ Calculează totalul cash nepredat
    const { rows } = await db.query(`
      SELECT COALESCE(SUM(p.amount), 0) AS total
      FROM payments p
      JOIN reservations r ON r.id = p.reservation_id
      JOIN trips t ON t.id = r.trip_id
      JOIN route_schedules rs ON rs.id = t.route_schedule_id
      WHERE rs.operator_id = $1
        AND p.status = 'paid'
        AND p.payment_method = 'cash'
        AND p.deposited_at IS NULL
    `, [operator_id]);

    const total = Number(rows[0]?.total || 0);
    if (total <= 0) {
      return res.status(400).json({ error: 'Nu există sume de predat.' });
    }

    // 2️⃣ Marchează plățile ca predate
    await db.query(`
      UPDATE payments
         SET deposited_at = NOW()
       WHERE id IN (
         SELECT p.id
         FROM payments p
         JOIN reservations r ON r.id = p.reservation_id
         JOIN trips t ON t.id = r.trip_id
         JOIN route_schedules rs ON rs.id = t.route_schedule_id
        WHERE rs.operator_id = $1
          AND p.status = 'paid'
          AND p.payment_method = 'cash'
          AND p.deposited_at IS NULL
       )
    `, [operator_id]);

    // 3️⃣ Salvează istoric predare
    await db.query(`
      INSERT INTO cash_handovers (employee_id, operator_id, amount)
      VALUES ($1, $2, $3)
    `, [employee_id, operator_id, total]);

    res.json({ success: true, amount: total });
  } catch (err) {
    console.error('[POST /api/reports/cash-handover]', err);
    res.status(500).json({ error: 'Eroare internă la predare totală.' });
  }
});
;





module.exports = router;
