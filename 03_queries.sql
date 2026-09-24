-- ============================================================================
-- W35 — the three route/timetable queries
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Query 1 — Upcoming trips
-- Every departure from now onward, with its route and operator.
-- (Workload 1: journey search — read-heavy, needs to be fast.)
-- ---------------------------------------------------------------------------
SELECT t.trip_id,
       r.short_name                              AS route,
       o.name                                    AS operator,
       to_char(t.departure_time, 'YYYY-MM-DD HH24:MI') AS departs,
       t.reserved_seats
FROM trips t
JOIN routes r    ON r.route_id = t.route_id
JOIN operators o ON o.operator_id = r.operator_id
WHERE t.departure_time > now()
ORDER BY t.departure_time;

-- ---------------------------------------------------------------------------
-- Query 2 — Ordered stops for a route
-- The stops on the loop route C1, in order. stop_sequence is what makes the
-- order explicit (and lets Central Station appear twice).
-- ---------------------------------------------------------------------------
SELECT rs.stop_sequence,
       s.name AS stop
FROM route_stops rs
JOIN stops s ON s.stop_id = rs.stop_id
WHERE rs.route_id = 2                -- C1
ORDER BY rs.stop_sequence;

-- ---------------------------------------------------------------------------
-- Query 3 — Routes with trip counts (including routes with no trips)
-- A LEFT JOIN so routes with zero trips (R2) still show up.
-- ---------------------------------------------------------------------------
SELECT r.short_name                        AS route,
       r.long_name                         AS description,
       count(t.trip_id)                    AS trip_count
FROM routes r
LEFT JOIN trips t ON t.route_id = r.route_id
GROUP BY r.route_id, r.short_name, r.long_name
ORDER BY r.short_name;
