-- ============================================================================
-- W36 — integrity write tests
-- For each rule: a VALID write (succeeds) and a REJECTED write (the constraint
-- or trigger fires). The whole script runs in one transaction that is rolled
-- back at the end, so the seed data is left untouched.
-- ============================================================================

BEGIN;

\echo '=== 1. Capacity: reserved_seats <= vehicle.capacity  (trigger enforce_capacity) ==='

-- VALID — trip 1 uses vehicle 1 (capacity 50); 45 seats is fine.
UPDATE trips SET reserved_seats = 45 WHERE trip_id = 1;
SELECT 'valid: reserved 45 seats' AS result;

-- REJECTED — 51 seats on a 50-seat bus.
DO $$
BEGIN
    UPDATE trips SET reserved_seats = 51 WHERE trip_id = 1;
    RAISE NOTICE 'FAIL: write was NOT rejected';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'REJECTED: %', SQLERRM;
END $$;

\echo '=== 2. Ticket status: only an issued ticket can be validated  (trigger enforce_validation_status) ==='

-- VALID — ticket 1 is "issued", so validating it is allowed.
INSERT INTO validations (ticket_id, vehicle_id) VALUES (1, 1);
SELECT 'valid: validated an issued ticket' AS result;

-- REJECTED — ticket 3 is "refunded".
DO $$
BEGIN
    INSERT INTO validations (ticket_id, vehicle_id) VALUES (3, 1);
    RAISE NOTICE 'FAIL: write was NOT rejected';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'REJECTED: %', SQLERRM;
END $$;

\echo '=== 3. Payment must equal ticket price  (trigger enforce_payment_amount) ==='

-- REJECTED — ticket 1 costs 25.00, but we try to record 30.00.
DO $$
BEGIN
    INSERT INTO payments (ticket_id, amount, currency) VALUES (1, 30.00, 'DKK');
    RAISE NOTICE 'FAIL: write was NOT rejected';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'REJECTED: %', SQLERRM;
END $$;

\echo '=== 4. Ticket status is a closed set  (CHECK constraint) ==='

-- REJECTED — "lost" is not a legal status.
DO $$
BEGIN
    INSERT INTO tickets (ticket_code, trip_id, product_code, status, price)
    VALUES ('TKT-X', 1, 'SINGLE', 'lost', 25.00);
    RAISE NOTICE 'FAIL: write was NOT rejected';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'REJECTED: %', SQLERRM;
END $$;

\echo '=== 5. Referential integrity  (FOREIGN KEY) ==='

-- REJECTED — there is no product with product_code 'NOPE'.
DO $$
BEGIN
    INSERT INTO tickets (ticket_code, trip_id, product_code, status, price)
    VALUES ('TKT-Y', 1, 'NOPE', 'issued', 25.00);
    RAISE NOTICE 'FAIL: write was NOT rejected';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'REJECTED: %', SQLERRM;
END $$;

\echo '=== 6. Ordered stops: position is unique, stop may repeat  (PRIMARY KEY) ==='

-- REJECTED — (route 1, sequence 1) already exists.
DO $$
BEGIN
    INSERT INTO route_stops (route_id, stop_sequence, stop_id) VALUES (1, 1, 4);
    RAISE NOTICE 'FAIL: write was NOT rejected';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'REJECTED: %', SQLERRM;
END $$;

-- VALID — same stop at a NEW sequence is allowed (that is what makes loops work).
INSERT INTO route_stops (route_id, stop_sequence, stop_id) VALUES (1, 4, 1);
SELECT 'valid: added Central Station again at position 4' AS result;

\echo '=== 7. Non-negative price  (CHECK constraint) ==='

-- REJECTED — negative price.
DO $$
BEGIN
    INSERT INTO products (product_code, name, price) VALUES ('BROKEN', 'Broken', -5.00);
    RAISE NOTICE 'FAIL: write was NOT rejected';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'REJECTED: %', SQLERRM;
END $$;

\echo '=== 8. A trip cannot arrive before it departs  (CHECK constraint) ==='

-- REJECTED — arrival earlier than departure.
DO $$
BEGIN
    INSERT INTO trips (route_id, service_date, departure_time, arrival_time)
    VALUES (1, now()::date, now(), now() - interval '1 hour');
    RAISE NOTICE 'FAIL: write was NOT rejected';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'REJECTED: %', SQLERRM;
END $$;

-- Undo all the test writes.
ROLLBACK;
