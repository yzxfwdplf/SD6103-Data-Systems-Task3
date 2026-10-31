SET search_path = housing, public; -- Point verification at the intended loaded schema.
SELECT 'town' AS table_name,count(*) AS row_count FROM town -- Verify all six base relations.
UNION ALL SELECT 'hdb_flat',count(*) FROM hdb_flat -- Check the participating address population.
UNION ALL SELECT 'resale_transaction',count(*) FROM resale_transaction -- Check the scoped sales.
UNION ALL SELECT 'hawker_centre',count(*) FROM hawker_centre -- Check the complete reference snapshot.
UNION ALL SELECT 'proximity_level',count(*) FROM proximity_level -- Check the three lookup intervals.
UNION ALL SELECT 'nearby',count(*) FROM nearby -- Check retained two-kilometre links.
ORDER BY table_name; -- Make the verification output easy to compare.
SELECT min(sale_month) AS earliest_month,max(sale_month) AS latest_month, -- Inspect actual bounds.
 count(DISTINCT sale_month) AS represented_months, -- Require all thirty-six monthly dates.
 count(*) FILTER (WHERE sale_month<DATE '2023-01-01' OR sale_month>=DATE '2026-01-01') AS out_of_scope -- Require zero.
FROM resale_transaction; -- Verify the actual loaded table rather than a report label.
SELECT count(*) FILTER (WHERE has_fresh_market IS TRUE) AS fresh_yes, -- Preserve confirmed yes.
 count(*) FILTER (WHERE has_fresh_market IS FALSE) AS fresh_no, -- Preserve confirmed no.
 count(*) FILTER (WHERE has_fresh_market IS NULL) AS fresh_unknown -- Preserve unknown status.
FROM hawker_centre; -- Expect 81, 23 and 25 in the supplied reference snapshot.
SELECT (SELECT count(*) FROM nearby) AS stored_links, -- Count all retained source pairs.
 (SELECT count(*) FROM nearby_classified) AS classified_links; -- Require the same 40,354 rows.
SELECT indexname,indexdef FROM pg_indexes -- Inspect whether optional analytical indexes exist.
WHERE schemaname=current_schema() ORDER BY tablename,indexname; -- Separate constraint and Task 4 indexes.
