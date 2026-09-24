-- ============================================================================
-- W38 — product-identity migration:  product_code  ->  product_id
--
-- WHY: product_code is a fine label but a poor identity — an operator may
-- rename a product. Tickets were linked to products by product_code; we move
-- them to a stable surrogate product_id using the EXPAND / CONTRACT pattern:
--
--   EXPAND    add the new column(s) alongside the old
--   BACKFILL  copy the relationship over for existing rows
--   OVERLAP   old and new writers both work (both columns live for a while)
--   VERIFY    prices & currencies are unchanged
--   CONTRACT  drop the old reference once nothing depends on it
--
-- Run AFTER 00_reset, 01_schema, 02_seed (and the W35–W37 scripts).
-- ============================================================================

BEGIN;

-- ===== EXPAND =====

-- 1. Products gain a stable surrogate id.
ALTER TABLE products ADD COLUMN product_id INT;
CREATE SEQUENCE products_product_id_seq;
UPDATE products SET product_id = nextval('products_product_id_seq');
ALTER TABLE products ALTER COLUMN product_id SET NOT NULL;
ALTER TABLE products ADD CONSTRAINT products_product_id_uq UNIQUE (product_id);

-- 2. Tickets gain a NULLABLE product_id (nullable during the overlap, because
--    the old writer doesn't know about it yet).
ALTER TABLE tickets ADD COLUMN product_id INT REFERENCES products(product_id);

-- ===== BACKFILL =====

-- Existing tickets resolve their product_id through the product_code they
-- already hold.
UPDATE tickets t
SET product_id = p.product_id
FROM products p
WHERE p.product_code = t.product_code;

-- ===== COMPATIBLE OVERLAP =====

-- An OLD writer (still running the pre-migration code, which only knows
-- product_code) adds a "late" ticket. It writes product_code and leaves
-- product_id NULL — that's exactly what must keep working during the overlap.
INSERT INTO tickets (ticket_code, trip_id, user_id, product_code, status, price, currency)
VALUES ('TKT-LATE-OLD', 1, 2, 'SINGLE', 'issued', 25.00, 'DKK');

-- ===== CHECKS BEFORE REMOVING THE OLD REFERENCE =====

-- The backfill job fills the gap the old writer left behind.
UPDATE tickets t
SET product_id = p.product_id
FROM products p
WHERE p.product_code = t.product_code AND t.product_id IS NULL;

-- Precondition for contract: no ticket is missing its product_id.
SELECT count(*) AS tickets_without_product_id
FROM tickets
WHERE product_id IS NULL;          -- expect 0

-- ===== PRICE EVIDENCE =====

-- Prices and currencies are unchanged by the migration (a hard requirement).
SELECT ticket_code, product_code, product_id, price, currency
FROM tickets
ORDER BY ticket_id;

-- ===== CONTRACT =====

-- The old reference can now go.
ALTER TABLE tickets ALTER COLUMN product_id SET NOT NULL;
ALTER TABLE tickets DROP COLUMN product_code;

-- product_id becomes the primary key; product_code is kept as a UNIQUE
-- business code (for display/search), not as identity.
ALTER TABLE products DROP CONSTRAINT products_pkey;
ALTER TABLE products ADD PRIMARY KEY (product_id);
ALTER TABLE products ALTER COLUMN product_id SET DEFAULT nextval('products_product_id_seq');
ALTER TABLE products ADD CONSTRAINT products_product_code_uq UNIQUE (product_code);

COMMIT;
