# Integrity map — MobilityTicketing

The running question of the whole course is:

> **"Can the database ever contain an invalid state?"**

Every rule below is enforced *in the database*, so no application or service —
old or new — can write data that breaks a rule. The map lists each rule, what
enforces it, and — just as important — what each mechanism **cannot** guarantee.

## The rules and what enforces them

### Declarative constraints (single table, single row)

| Rule | Enforced by |
|---|---|
| A route belongs to exactly one operator | `FOREIGN KEY routes.operator_id` + `NOT NULL` |
| A stop's position on a route is unique | `PRIMARY KEY (route_id, stop_sequence)` |
| A stop *may* repeat on a route (loops) | *deliberately not* unique on `(route_id, stop_id)` |
| Sequence numbers start at 1 | `CHECK (stop_sequence >= 1)` |
| Vehicle capacity is non-negative | `CHECK (capacity >= 0)` |
| A trip departs before it arrives | `CHECK (departure_time < arrival_time)` |
| Reserved seats non-negative | `CHECK (reserved_seats >= 0)` |
| Ticket status is a closed set | `CHECK (status IN ('issued','used','refunded'))` |
| Prices are non-negative | `CHECK (price >= 0)` |
| A ticket references a real product/trip/user | `FOREIGN KEY` on each |
| One payment settles one ticket | `UNIQUE (payments.ticket_id)` |

### Triggers (rules that span two tables)

A `CHECK` can only see the row being written, so three rules that span tables
are enforced with triggers (see `04_integrity.sql`):

| Rule | Trigger |
|---|---|
| `reserved_seats <= vehicle.capacity` | `trips_capacity_check` |
| `payments.amount = tickets.price` | `payments_amount_check` |
| Only an `issued` ticket may be validated | `validations_status_check` |

## Boundaries — what the constraints do *not* guarantee

1. **Cross-table rules need triggers.** A `CHECK` constraint cannot read another
   table, so rules like "reserved seats ≤ capacity" cannot be a `CHECK` — they
   must be a trigger (or enforced in the application, which is weaker).

2. **The capacity trigger is not race-safe under concurrency.** Two purchases at
   the same instant can both read `reserved_seats = 40, capacity = 50` and both
   pass the check before either commits. A row-level trigger cannot prevent
   that; it needs `SERIALIZABLE` isolation or an explicit lock. This is the
   classic difference between "constraints keep *a* state valid" and "the
   system stays valid *under load*".

3. **Triggers can be bypassed.** A privileged user can `ALTER TABLE ... DISABLE
   TRIGGER`, and triggers don't fire on bulk loads (`COPY`, `TRUNCATE`).

4. **Aggregate invariants are hard to state declaratively.** "Total reserved
   seats across all trips never exceeds the fleet capacity" is a global rule
   that no simple `CHECK` or single-table trigger can express.

The integrity map is the point: most rules *are* cheaply enforceable in the
database, but a few are not — and knowing which is which is the actual skill.
