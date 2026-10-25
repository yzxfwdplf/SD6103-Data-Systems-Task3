SET search_path = housing, public;

SELECT 'town' AS table_name, count(*) AS row_count FROM town
UNION ALL SELECT 'hdb_flat', count(*) FROM hdb_flat
UNION ALL SELECT 'resale_transaction', count(*) FROM resale_transaction
UNION ALL SELECT 'hawker_centre', count(*) FROM hawker_centre
UNION ALL SELECT 'proximity_level', count(*) FROM proximity_level
UNION ALL SELECT 'nearby', count(*) FROM nearby
ORDER BY table_name;

SELECT min(sale_month) AS earliest_month,
       max(sale_month) AS latest_month,
       count(DISTINCT date_trunc('month', sale_month)) AS represented_months
FROM resale_transaction;

SELECT count(*) FILTER (WHERE has_fresh_market IS TRUE) AS fresh_yes,
       count(*) FILTER (WHERE has_fresh_market IS FALSE) AS fresh_no,
       count(*) FILTER (WHERE has_fresh_market IS NULL) AS fresh_unknown
FROM hawker_centre;

SELECT
    (SELECT count(*) FROM resale_transaction rt LEFT JOIN hdb_flat f USING (flat_id) WHERE f.flat_id IS NULL) AS orphan_transactions,
    (SELECT count(*) FROM hdb_flat f LEFT JOIN town t USING (town_id) WHERE t.town_id IS NULL) AS orphan_flats,
    (SELECT count(*) FROM nearby n LEFT JOIN hdb_flat f USING (flat_id) WHERE f.flat_id IS NULL) AS orphan_nearby_flats,
    (SELECT count(*) FROM nearby n LEFT JOIN hawker_centre h USING (hawker_id) WHERE h.hawker_id IS NULL) AS orphan_nearby_hawkers;

SELECT CASE
           WHEN (SELECT count(*) FROM town) = 26
            AND (SELECT count(*) FROM hdb_flat) = 9852
            AND (SELECT count(*) FROM resale_transaction) = 976441
            AND (SELECT count(*) FROM hawker_centre) = 129
            AND (SELECT count(*) FROM proximity_level) = 3
            AND (SELECT count(*) FROM nearby) = 43036
           THEN 'PASS: all expected row counts match'
           ELSE 'CHECK: one or more row counts differ'
       END AS import_status;
