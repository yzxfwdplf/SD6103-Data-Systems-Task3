SET search_path = housing, public; -- Use a freshly loaded merged database.
-- Reference DDL only: the runners test each candidate in isolation; do not benchmark this all-index set.

-- Candidate team_generic: Control: the teammate's additional transaction indexes; date covers the full scope and lease appears in CASE rather than a selective WHERE.
CREATE INDEX t4_team_month_type ON resale_transaction(sale_month,flat_type); -- Re-test the teammate's general date/type index.
CREATE INDEX t4_team_flat ON resale_transaction(flat_id); -- Re-test the teammate's foreign-key lookup index.
CREATE INDEX t4_team_lease ON resale_transaction(remaining_lease_months); -- Test whether CASE grouping benefits in practice.

-- Candidate nearest_order: Q4 DISTINCT ON needs the same flat_id/distance_m/hawker_id order; all needed relationship columns are in the index.
CREATE INDEX t4_nearby_nearest ON nearby(flat_id,distance_m,hawker_id); -- Supply Q4's nearest-centre order from a covering B-tree.

-- Candidate partial_3room: Q3 uses only 3 ROOM observations in both stages; the index excludes other types and covers required sale values.
CREATE INDEX t4_resale_3room ON resale_transaction(flat_id,sale_month) INCLUDE(floor_area_sqm,resale_price) WHERE flat_type='3 ROOM'; -- Cover both selective Q3 passes.

-- Candidate partial_45room: Q1 uses 4 ROOM and 5 ROOM only; cover all referenced transaction columns without relying on an unselective date bound.
CREATE INDEX t4_resale_45room ON resale_transaction(flat_type,flat_id) INCLUDE(sale_month,resale_price,floor_area_sqm) WHERE flat_type IN ('4 ROOM','5 ROOM'); -- Cover the Q1 room-type subset.

-- Candidate sale_cover: All six queries read a narrower set than the wide transaction row; test index-only scans with a shared covering index.
CREATE INDEX t4_resale_cover ON resale_transaction(flat_id) INCLUDE(sale_month,flat_type,remaining_lease_months,resale_price,floor_area_sqm); -- Cover repeated transaction-side reads for Q1-Q6.

-- Candidate hawker_links: Q5 filters centres by fresh-market status; test a covering join path from selected hawkers into nearby links.
CREATE INDEX t4_nearby_hawker ON nearby(hawker_id,flat_id) INCLUDE(distance_m); -- Cover centre-to-address joins used by Q5 and Q6.

-- Candidate town_addresses: Test the teammate's town-to-address access path with a covering key order on the small address table.
CREATE INDEX t4_flat_town ON hdb_flat(town_id,flat_id); -- Cover town-to-address joins while retaining stable address keys.
