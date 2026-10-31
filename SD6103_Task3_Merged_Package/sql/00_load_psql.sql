\set ON_ERROR_STOP on
-- Run from the project root against a new database/schema: psql -f sql/00_load_psql.sql.
\i sql/01_schema.sql
SET search_path = housing, public; -- Use the newly created housing schema.
-- Bulk-load the audited town CSV using its explicit column order.
\copy housing.town (town_id,town_name) FROM 'data/processed/town.csv' WITH (FORMAT CSV,HEADER TRUE)
-- Bulk-load the audited hdb_flat CSV using its explicit column order.
\copy housing.hdb_flat (flat_id,town_id,block,street_name,postal_code,latitude,longitude) FROM 'data/processed/hdb_flat.csv' WITH (FORMAT CSV,HEADER TRUE)
-- Bulk-load the audited hawker_centre CSV using its explicit column order.
\copy housing.hawker_centre (hawker_id,hawker_name,address,latitude,longitude,market_stall_count) FROM 'data/processed/hawker_centre.csv' WITH (FORMAT CSV,HEADER TRUE)
-- Bulk-load the audited proximity_level CSV using its explicit column order.
\copy housing.proximity_level (proximity_level_id,level_name,min_distance_m,max_distance_m,upper_inclusive) FROM 'data/processed/proximity_level.csv' WITH (FORMAT CSV,HEADER TRUE)
-- Bulk-load the audited nearby CSV using its explicit column order.
\copy housing.nearby (flat_id,hawker_id,distance_m) FROM 'data/processed/nearby.csv' WITH (FORMAT CSV,HEADER TRUE)
-- Bulk-load the audited resale_transaction CSV using its explicit column order.
\copy housing.resale_transaction (transaction_id,flat_id,sale_month,flat_type,storey_range,floor_area_sqm,flat_model,lease_commence_year,remaining_lease_months,resale_price,source_row_key) FROM 'data/processed/resale_transaction.csv' WITH (FORMAT CSV,HEADER TRUE)
VACUUM (ANALYZE); -- Establish the same read-mostly visibility state as the benchmark.
\i sql/03_verify.sql
-- Run sql/04_queries.sql next; do not create Task 4 indexes before recording the baseline.
