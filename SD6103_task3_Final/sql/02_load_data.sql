\set ON_ERROR_STOP on
\timing on
SET search_path = housing, public;

BEGIN;
\copy town (town_id, town_name) FROM 'data/town.csv' WITH (FORMAT csv, HEADER true)
\copy hdb_flat (flat_id, town_id, block, street_name, postal_code, latitude, longitude) FROM 'data/hdb_flat.csv' WITH (FORMAT csv, HEADER true)
\copy resale_transaction (transaction_id, flat_id, source_row_key, sale_month, flat_type, storey_range, floor_area_sqm, flat_model, lease_commence_year, remaining_lease_months, resale_price) FROM 'data/resale_transaction.csv' WITH (FORMAT csv, HEADER true)
\copy hawker_centre (hawker_id, hawker_name, address, latitude, longitude, market_stall_count) FROM 'data/hawker_centre.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy nearby (flat_id, hawker_id, distance_m) FROM 'data/nearby.csv' WITH (FORMAT csv, HEADER true)

INSERT INTO proximity_level
    (proximity_level_id, level_name, min_distance_m, max_distance_m, upper_inclusive)
VALUES
    (1, 'near',   0,    500,  false),
    (2, 'medium', 500,  1000, false),
    (3, 'far',    1000, 2000, true);
COMMIT;

CREATE INDEX idx_hdb_flat_town ON hdb_flat (town_id);
CREATE INDEX idx_resale_month_type ON resale_transaction (sale_month, flat_type);
CREATE INDEX idx_resale_flat ON resale_transaction (flat_id);
CREATE INDEX idx_resale_lease ON resale_transaction (remaining_lease_months);
CREATE INDEX idx_nearby_flat_distance ON nearby (flat_id, distance_m, hawker_id);
CREATE INDEX idx_nearby_hawker ON nearby (hawker_id);
CREATE INDEX idx_hawker_fresh ON hawker_centre (has_fresh_market);

ANALYZE town;
ANALYZE hdb_flat;
ANALYZE resale_transaction;
ANALYZE hawker_centre;
ANALYZE nearby;

CREATE OR REPLACE VIEW v_nearby_classified AS
SELECT n.flat_id,
       n.hawker_id,
       n.distance_m,
       pl.proximity_level_id,
       pl.level_name AS proximity_class
FROM nearby AS n
JOIN proximity_level AS pl
  ON n.distance_m >= pl.min_distance_m
 AND (n.distance_m < pl.max_distance_m
      OR (pl.upper_inclusive AND n.distance_m <= pl.max_distance_m));
