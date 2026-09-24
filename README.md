# Compulsory Assignment 1 — MobilityTicketing

A small PostgreSQL model of a public-transport ticketing platform (buses, trams
and trains), built over weeks 35 to 38.

**Submitted commit:** `10da5b1`

## Setup and reset

Plain PostgreSQL 14 SQL, no Docker. Run in this order:

```
psql -d <db> -f 00_reset.sql
psql -d <db> -f 01_schema.sql
psql -d <db> -f 02_seed.sql
```

The other scripts below are each self-contained (several run inside a
transaction they roll back, so the seed data stays untouched).

## Where to find the work

- **Lecture 1, model and queries:** `01_schema.sql` (schema), `02_seed.sql`
  (seed data), `03_queries.sql` (the three route/timetable queries).
- **Lecture 2, constraints and tests:** `INTEGRITY.md` (the integrity map),
  `04_integrity.sql` (the triggers), `05_integrity_tests.sql` (valid and
  rejected writes).
- **Lecture 3, reporting:** `06_reporting.sql` (the `daily_revenue_by_operator()`
  function, the `mv_daily_revenue` materialized view, and the stale-result run).
- **Lecture 4, migration:** `migrations/001_product_identity.sql` (the
  expand/contract move from `product_code` to `product_id`).

## Two decisions worth discussing

**1. Ordering stops with `(route_id, stop_sequence)`, not `(route_id, stop_id)`.**

A route can visit the same stop more than once. The C1 loop goes Central →
Old Town → Museum → Central, so a key of `(route_id, stop_id)` would collide on
the second Central and the loop could not be stored. What is unique is the
*position*, so that is what the key uses. Evidence: the `route_stops` primary
key in `01_schema.sql`, the C1 row hitting stop 1 twice in `02_seed.sql`, and
query 2 in `03_queries.sql`, which prints Central Station at positions 1 and 4.

A surrogate `route_stop_id` would also work, but the composite key states the
rule ("a position on a route is unique") in the schema instead of leaving it
implicit.

**2. Snapshotting price and currency onto the ticket.**

A ticket keeps the price it was actually sold at, rather than joining to the
product's current price. Raise the day-pass price tomorrow and yesterday's
tickets must still show what was paid. That is a correctness rule, not a
presentation choice. It is also why the W38 migration insists existing prices
stay unchanged: `migrations/001_product_identity.sql` ends by printing the
price and currency columns to prove it.

Joining to the product for the price is simpler but breaks the moment a price
changes or a product is renamed, which is exactly what the migration fixes.

## One limitation

The capacity rule (`reserved_seats <= vehicle.capacity`) lives in a trigger and
is not race-safe. Two purchases at the same instant can both read "40 seats,
50 capacity" and both pass before either commits. A row-level trigger cannot
stop that. What we would check next is whether the purchase path can interleave
like that in practice, and if so, lock the trip row before incrementing
reserved seats.
