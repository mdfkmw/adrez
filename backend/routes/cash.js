// backend/routes/cash.js
const express = require('express');
const router  = express.Router();
const db      = require('../db');

/**
 * GET /api/cash/unsettled?employeeId=1
 * Returnează ce bani are de predat agentul (DOAR CASH, nepredați), grupați pe operator.
 */
router.get('/unsettled', async (req, res) => {
  try {
    const employeeId = Number(req.query.employeeId);
    if (!employeeId) return res.status(400).json({ error: 'employeeId required' });

    const sql = `
      WITH elig AS (
        SELECT
          p.id            AS payment_id,
          p.amount        AS amount,
          rs.operator_id  AS operator_id,
          o.name          AS operator_name
        FROM public.payments p
        JOIN public.reservations r ON r.id = p.reservation_id
        JOIN public.trips t        ON t.id = r.trip_id
        JOIN public.route_schedules rs ON rs.id = t.route_schedule_id
        JOIN public.operators o        ON o.id = rs.operator_id
        WHERE
          p.status = 'paid'
          AND p.payment_method = 'cash'
          AND p.cash_handover_id IS NULL
          AND p.collected_by = $1
      )
      SELECT
        operator_id,
        operator_name,
        COUNT(*)              AS payments_count,
        COALESCE(SUM(amount),0)::numeric AS total_amount,
        ARRAY_AGG(payment_id) AS payment_ids
      FROM elig
      GROUP BY operator_id, operator_name
      ORDER BY operator_name;
    `;
    const { rows } = await db.query(sql, [employeeId]);
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to fetch unsettled cash' });
  }
});

/**
 * POST /api/cash/handovers/preda
 * Body: { "employeeId": 1 }
 * Creează handover-uri (câte unul per operator) și marchează plățile ca predate.
 */
router.post('/handovers/preda', async (req, res) => {
  const client = await db.connect();
  try {
    const employeeId = Number(req.body.employeeId);
    if (!employeeId) {
      client.release();
      return res.status(400).json({ error: 'employeeId required' });
    }

    await client.query('BEGIN');

    // Selectăm plățile eligibile și le grupăm pe operator, blocându-le pentru tranzacția curentă
    const eligSql = `
      WITH elig AS (
        SELECT
          p.id           AS payment_id,
          p.amount       AS amount,
          rs.operator_id AS operator_id
        FROM public.payments p
        JOIN public.reservations r ON r.id = p.reservation_id
        JOIN public.trips t        ON t.id = r.trip_id
        JOIN public.route_schedules rs ON rs.id = t.route_schedule_id
        WHERE
          p.status = 'paid'
          AND p.payment_method = 'cash'
          AND p.cash_handover_id IS NULL
          AND p.collected_by = $1
        FOR UPDATE SKIP LOCKED
      )
      SELECT operator_id,
             COALESCE(SUM(amount),0)::numeric AS total_amount,
             ARRAY_AGG(payment_id)            AS payment_ids
      FROM elig
      GROUP BY operator_id;
    `;
    const { rows } = await client.query(eligSql, [employeeId]);

    const results = [];
    for (const row of rows) {
      const { operator_id, total_amount, payment_ids } = row;
      if (!payment_ids || payment_ids.length === 0) continue;

      // 1) Inserăm handover pe operator
      const ins = await client.query(
        'INSERT INTO public.cash_handovers (employee_id, operator_id, amount, created_at) VALUES ($1,$2,$3,NOW()) RETURNING id, created_at',
        [employeeId, operator_id, total_amount]
      );
      const handoverId = ins.rows[0].id;

      // 2) Legăm plățile de handover
      await client.query(
        'UPDATE public.payments SET cash_handover_id = $1 WHERE id = ANY($2)',
        [handoverId, payment_ids]
      );

      results.push({
        handoverId,
        operatorId: operator_id,
        amount: total_amount,
        paymentsCount: payment_ids.length,
        createdAt: ins.rows[0].created_at
      });
    }

    await client.query('COMMIT');
    client.release();
    res.json({ ok: true, handovers: results });
  } catch (e) {
    await client.query('ROLLBACK');
    client.release();
    console.error(e);
    res.status(500).json({ error: 'Failed to handover cash' });
  }
});

/**
 * GET /api/cash/handovers/history?employeeId=1
 * Istoric predări ale agentului curent
 */
router.get('/handovers/history', async (req, res) => {
  try {
    const employeeId = Number(req.query.employeeId);
    if (!employeeId) return res.status(400).json({ error: 'employeeId required' });

    const sql = `
      SELECT
        ch.id,
        ch.created_at,
        ch.operator_id,
        o.name AS operator_name,
        ch.amount,
        COUNT(p.id) AS payments_count
      FROM public.cash_handovers ch
      JOIN public.operators o ON o.id = ch.operator_id
      LEFT JOIN public.payments p ON p.cash_handover_id = ch.id
      WHERE ch.employee_id = $1
      GROUP BY ch.id, ch.created_at, ch.operator_id, o.name, ch.amount
      ORDER BY ch.created_at DESC;
    `;
    const { rows } = await db.query(sql, [employeeId]);
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to fetch handover history' });
  }
});

module.exports = router;
