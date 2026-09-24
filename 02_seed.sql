-- ============================================================================
-- MobilityTicketing — seed data
-- Timestamps for trips are expressed relative to now() so the "upcoming trips"
-- query always returns a sensible result regardless of when it is run.
-- ============================================================================

BEGIN;

-- Operators
INSERT INTO operators (name) VALUES
  ('MetroBus'),
  ('CityRail'),
  ('TramCo');

-- Stops
INSERT INTO stops (name) VALUES
  ('Central Station'),
  ('Airport'),
  ('University'),
  ('Harbour'),
  ('Old Town'),
  ('Museum');

-- Routes
INSERT INTO routes (operator_id, short_name, long_name) VALUES
  (1, '5A', 'Central – University – Harbour'),
  (1, 'C1', 'City circular (loop)'),
  (3, 'T9', 'Airport – Central'),
  (2, 'R2', 'Regional express');

-- route_stops  (route_id, stop_sequence, stop_id)
-- 5A: Central -> University -> Harbour
INSERT INTO route_stops (route_id, stop_sequence, stop_id) VALUES
  (1, 1, 1),   -- Central Station
  (1, 2, 3),   -- University
  (1, 3, 4);   -- Harbour

-- C1: a LOOP — Central -> Old Town -> Museum -> Central (Central appears twice!)
INSERT INTO route_stops (route_id, stop_sequence, stop_id) VALUES
  (2, 1, 1),   -- Central Station
  (2, 2, 5),   -- Old Town
  (2, 3, 6),   -- Museum
  (2, 4, 1);   -- Central Station again

-- T9: Airport -> Central
INSERT INTO route_stops (route_id, stop_sequence, stop_id) VALUES
  (3, 1, 2),   -- Airport
  (3, 2, 1);   -- Central Station

-- R2 has NO route_stops yet (and no trips) — used by the "routes with no trips" query.

-- Vehicles
INSERT INTO vehicles (operator_id, type, capacity) VALUES
  (1, 'bus',   50),
  (1, 'bus',   50),
  (3, 'tram',  80),
  (2, 'train', 200);

-- Trips  (route_id, vehicle_id, service_date, departure_time, arrival_time, reserved_seats)
INSERT INTO trips (route_id, vehicle_id, service_date, departure_time, arrival_time, reserved_seats) VALUES
  -- 5A — one upcoming in 3h, one upcoming tomorrow, one past
  (1, 1, (now() + interval '3 hours')::date,  now() + interval '3 hours',  now() + interval '3 hours 40 minutes', 12),
  (1, 2, (now() + interval '1 day')::date,   now() + interval '1 day',     now() + interval '1 day 40 minutes',    0),
  (1, 1, (now() - interval '1 day')::date,   now() - interval '1 day 40 minutes', now() - interval '1 day',           30),
  -- C1 loop — upcoming in 2h
  (2, 2, (now() + interval '2 hours')::date, now() + interval '2 hours',   now() + interval '2 hours 30 minutes', 5),
  -- T9 — upcoming in 6h
  (3, 3, (now() + interval '6 hours')::date, now() + interval '6 hours',   now() + interval '6 hours 25 minutes', 40);

-- Users
INSERT INTO users (name, email) VALUES
  ('Ada Lovelace', 'ada@example.com'),
  ('Alan Turing',  'alan@example.com');

-- Products
INSERT INTO products (product_code, name, price, currency) VALUES
  ('SINGLE',   'Single ticket', 25.00, 'DKK'),
  ('DAY-PASS', 'Day pass',      60.00, 'DKK');

-- Tickets  (ticket_code, trip_id, user_id, product_id, status, price, currency, purchased_at)
INSERT INTO tickets (ticket_code, trip_id, user_id, product_code, status, price, currency, purchased_at) VALUES
  ('TKT-0001', 1, 1, 'SINGLE',   'issued',  25.00, 'DKK', now() - interval '1 hour'),
  ('TKT-0002', 1, 2, 'SINGLE',   'used',    25.00, 'DKK', now() - interval '2 hours'),
  ('TKT-0003', 3, 1, 'DAY-PASS', 'refunded', 60.00, 'DKK', now() - interval '2 days');

-- Payments
INSERT INTO payments (ticket_id, amount, currency, paid_at) VALUES
  (1, 25.00, 'DKK', now() - interval '1 hour'),
  (2, 25.00, 'DKK', now() - interval '2 hours'),
  (3, 60.00, 'DKK', now() - interval '2 days');

-- Validations
INSERT INTO validations (ticket_id, vehicle_id, validated_at) VALUES
  (2, 1, now() - interval '90 minutes');

COMMIT;
