-- ============================================================================
-- Reset — drop every MobilityTicketing table.
-- Run this first, then 01_schema.sql, then 02_seed.sql, against an empty DB.
-- ============================================================================

DROP TABLE IF EXISTS
  validations,
  payments,
  tickets,
  products,
  users,
  trips,
  vehicles,
  route_stops,
  stops,
  routes,
  operators
CASCADE;
