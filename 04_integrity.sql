-- ============================================================================
-- W36/W37 — integrity rules that need MORE than a CHECK constraint
--
-- A CHECK constraint can only look at the row being written. Three of our
-- rules span two tables, so they must be enforced with a trigger (W37
-- programmability). Each rule below says WHY it can't be a plain CHECK.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Rule A — "A trip can never reserve more seats than its vehicle has."
-- Cross-table (trips -> vehicles). CHECK cannot read vehicles.capacity.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION enforce_capacity() RETURNS trigger AS $$
DECLARE
    cap INT;
BEGIN
    SELECT v.capacity INTO cap
    FROM vehicles v
    WHERE v.vehicle_id = NEW.vehicle_id;

    IF cap IS NOT NULL AND NEW.reserved_seats > cap THEN
        RAISE EXCEPTION 'reserved_seats (%) exceeds vehicle capacity (%)',
            NEW.reserved_seats, cap;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trips_capacity_check
BEFORE INSERT OR UPDATE OF reserved_seats, vehicle_id ON trips
FOR EACH ROW EXECUTE FUNCTION enforce_capacity();

-- ---------------------------------------------------------------------------
-- Rule B — "A payment must equal the ticket's price."
-- Cross-table (payments -> tickets). Prevents over/under-charging.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION enforce_payment_amount() RETURNS trigger AS $$
DECLARE
    tk_price NUMERIC(10,2);
BEGIN
    SELECT t.price INTO tk_price
    FROM tickets t
    WHERE t.ticket_id = NEW.ticket_id;

    IF tk_price IS NOT NULL AND NEW.amount <> tk_price THEN
        RAISE EXCEPTION 'payment amount (%) does not match ticket price (%)',
            NEW.amount, tk_price;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER payments_amount_check
BEFORE INSERT OR UPDATE OF amount ON payments
FOR EACH ROW EXECUTE FUNCTION enforce_payment_amount();

-- ---------------------------------------------------------------------------
-- Rule C — "Only an 'issued' ticket may be validated (used)."
-- Cross-table (validations -> tickets). Closes the door on double-riding and
-- on validating a refunded ticket.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION enforce_validation_status() RETURNS trigger AS $$
DECLARE
    tk_status TEXT;
BEGIN
    SELECT t.status INTO tk_status
    FROM tickets t
    WHERE t.ticket_id = NEW.ticket_id;

    IF tk_status IS NULL OR tk_status <> 'issued' THEN
        RAISE EXCEPTION 'cannot validate a ticket with status "%"', tk_status;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validations_status_check
BEFORE INSERT ON validations
FOR EACH ROW EXECUTE FUNCTION enforce_validation_status();
