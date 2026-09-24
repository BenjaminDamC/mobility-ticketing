-- ============================================================================
-- W37 — reporting: function + materialized view + the "stale result" experiment
--
-- RESPONSIBILITY DECISION (where does reporting logic live?):
--   * Base tables are the SOURCE OF TRUTH — always correct.
--   * mv_daily_revenue is a PRECOMPUTED CACHE for the reporting workload
--     (workload 6: reporting tolerates latency), so it can go STALE.
--   * daily_revenue_by_operator() is the reusable, always-fresh query.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- The always-fresh reporting function (reads base tables).
-- Refunded tickets are excluded: a refund is money returned, not revenue.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION daily_revenue_by_operator()
RETURNS TABLE (operator text, tickets_sold bigint, revenue numeric) AS $$
    SELECT o.name                         AS operator,
           count(tk.ticket_id)            AS tickets_sold,
           coalesce(sum(tk.price), 0)     AS revenue
    FROM tickets tk
    JOIN trips     tr ON tr.trip_id   = tk.trip_id
    JOIN routes    r  ON r.route_id   = tr.route_id
    JOIN operators o  ON o.operator_id = r.operator_id
    WHERE tk.status <> 'refunded'
    GROUP BY o.name
    ORDER BY revenue DESC;
$$ LANGUAGE sql;

-- ---------------------------------------------------------------------------
-- The precomputed cache (materialized view) — fast, but only as fresh as its
-- last REFRESH.
-- ---------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS mv_daily_revenue;
CREATE MATERIALIZED VIEW mv_daily_revenue AS
SELECT o.name                                 AS operator,
       count(tk.ticket_id)                    AS tickets_sold,
       coalesce(sum(tk.price), 0)             AS revenue
FROM tickets tk
JOIN trips     tr ON tr.trip_id   = tk.trip_id
JOIN routes    r  ON r.route_id   = tr.route_id
JOIN operators o  ON o.operator_id = r.operator_id
WHERE tk.status <> 'refunded'
GROUP BY o.name
ORDER BY revenue DESC;

-- ============================================================================
-- The stale-result experiment (runs in one transaction that is rolled back)
-- ============================================================================
BEGIN;

\echo '--- 1. Materialized view BEFORE the new sale (current cache) ---'
SELECT * FROM mv_daily_revenue;

\echo '--- 2. A new sale happens: a ticket on trip 5 (TramCo route) ---'
INSERT INTO tickets (ticket_code, trip_id, user_id, product_id, status, price, currency)
VALUES ('TKT-NEW', 5, 1, 1, 'issued', 25.00, 'DKK');

\echo '--- 3. Base-table function — sees the new sale immediately (correct) ---'
SELECT * FROM daily_revenue_by_operator();

\echo '--- 4. Materialized view — STALE: it does NOT include the new sale ---'
SELECT * FROM mv_daily_revenue;

\echo '--- 5. Refresh the cache ---'
REFRESH MATERIALIZED VIEW mv_daily_revenue;

\echo '--- 6. Materialized view — now correct ---'
SELECT * FROM mv_daily_revenue;

-- Undo the test sale (and the refresh) so the seed stays pristine.
ROLLBACK;
