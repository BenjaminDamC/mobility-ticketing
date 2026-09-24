-- ============================================================================
-- MobilityTicketing — schema
-- Databases for Developers (E2026) — Compulsory Assignment #1
--
-- Design philosophy (the running thread of the course):
--   "Can the database ever contain an invalid state?"
-- Every business rule below is enforced *in the database*, so no matter which
-- application or service writes, an invalid write is rejected.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Operators: the transport companies (bus/tram/train) that run the service.
-- ---------------------------------------------------------------------------
CREATE TABLE operators (
    operator_id   SERIAL PRIMARY KEY,
    name          TEXT NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------------
-- Routes: a named line (e.g. "5A") operated by exactly ONE operator.
--   route -> operator : one operator runs many routes.
-- ---------------------------------------------------------------------------
CREATE TABLE routes (
    route_id      SERIAL PRIMARY KEY,
    operator_id   INT  NOT NULL REFERENCES operators(operator_id),
    short_name    TEXT NOT NULL UNIQUE,          -- e.g. '5A'
    long_name     TEXT                            -- e.g. 'City Centre – Airport'
);

-- ---------------------------------------------------------------------------
-- Stops: a stop/station. Shared across routes (a stop belongs to many routes).
-- ---------------------------------------------------------------------------
CREATE TABLE stops (
    stop_id       SERIAL PRIMARY KEY,
    name          TEXT NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------------
-- route_stops: the ordered stops along a route (many-to-many + order).
--
-- KEY DECISION (the "ordered stops" workload):
--   A route may visit the SAME stop more than once (loop routes), so
--   (route_id, stop_id) is NOT unique. What *is* unique is a stop's POSITION
--   on the route. Hence PRIMARY KEY (route_id, stop_sequence).
-- ---------------------------------------------------------------------------
CREATE TABLE route_stops (
    route_id       INT NOT NULL REFERENCES routes(route_id) ON DELETE CASCADE,
    stop_sequence  INT NOT NULL,
    stop_id        INT NOT NULL REFERENCES stops(stop_id),
    PRIMARY KEY (route_id, stop_sequence),
    CHECK (stop_sequence >= 1)                   -- positions start at 1
);

-- ---------------------------------------------------------------------------
-- Vehicles: buses/trams/trains, each with a seating capacity.
-- ---------------------------------------------------------------------------
CREATE TABLE vehicles (
    vehicle_id    SERIAL PRIMARY KEY,
    operator_id   INT  NOT NULL REFERENCES operators(operator_id),
    type          TEXT NOT NULL CHECK (type IN ('bus','tram','train')),
    capacity      INT  NOT NULL CHECK (capacity >= 0)
);

-- ---------------------------------------------------------------------------
-- Trips: a scheduled run of a route at a given time.
--
-- KEY DECISION (normalisation): operator_id is deliberately NOT stored here.
--   route_id -> operator_id -> operator_name is a TRANSITIVE dependency; the
--   operator is reachable through route_id, so storing it again on trips would
--   create redundancy and the chance of contradictory copies. (W36 quiz Q4.)
-- ---------------------------------------------------------------------------
CREATE TABLE trips (
    trip_id        SERIAL PRIMARY KEY,
    route_id       INT  NOT NULL REFERENCES routes(route_id),
    vehicle_id     INT  REFERENCES vehicles(vehicle_id),   -- assigned later
    service_date   DATE NOT NULL,
    departure_time TIMESTAMPTZ NOT NULL,
    arrival_time   TIMESTAMPTZ NOT NULL,
    reserved_seats INT  NOT NULL DEFAULT 0 CHECK (reserved_seats >= 0),
    CHECK (departure_time < arrival_time)         -- a trip can't arrive before it leaves
);

-- ---------------------------------------------------------------------------
-- Users: customers who buy and validate tickets.
-- ---------------------------------------------------------------------------
CREATE TABLE users (
    user_id       SERIAL PRIMARY KEY,
    name          TEXT NOT NULL,
    email         TEXT UNIQUE
);

-- ---------------------------------------------------------------------------
-- Products: ticket products (single, day pass, ...).
--
--   product_code = the business code, used as the identity UNTIL W38, when the
--                  migration introduces a stable surrogate product_id.
-- ---------------------------------------------------------------------------
CREATE TABLE products (
    product_code  TEXT PRIMARY KEY,
    name          TEXT NOT NULL,
    price         NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    currency      TEXT NOT NULL DEFAULT 'DKK'
);

-- ---------------------------------------------------------------------------
-- Tickets: a purchased ticket for a specific trip.
--
--   price/currency are a SNAPSHOT of the product price at purchase time.
--   This is deliberate: changing a product's price later must NOT change the
--   price an existing ticket was sold at (a W38 requirement).
--
--   product_code references the product UNTIL W38, when the migration moves
--   tickets to the stable product_id.
--
--   status is a small state machine: issued -> used | issued -> refunded.
-- ---------------------------------------------------------------------------
CREATE TABLE tickets (
    ticket_id     SERIAL PRIMARY KEY,
    ticket_code   TEXT NOT NULL UNIQUE,          -- scan code shown to the inspector
    trip_id       INT  NOT NULL REFERENCES trips(trip_id),
    user_id       INT  REFERENCES users(user_id),
    product_code  TEXT NOT NULL REFERENCES products(product_code),
    status        TEXT NOT NULL DEFAULT 'issued'
                  CHECK (status IN ('issued','used','refunded')),
    price         NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    currency      TEXT NOT NULL DEFAULT 'DKK',
    purchased_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Payments: one payment settles one ticket.
-- ---------------------------------------------------------------------------
CREATE TABLE payments (
    payment_id    SERIAL PRIMARY KEY,
    ticket_id     INT  NOT NULL UNIQUE REFERENCES tickets(ticket_id),
    amount        NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
    currency      TEXT NOT NULL,
    paid_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Validations: a ticket being checked/used when a passenger boards.
-- ---------------------------------------------------------------------------
CREATE TABLE validations (
    validation_id SERIAL PRIMARY KEY,
    ticket_id     INT  NOT NULL REFERENCES tickets(ticket_id),
    vehicle_id    INT  REFERENCES vehicles(vehicle_id),
    validated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMIT;
