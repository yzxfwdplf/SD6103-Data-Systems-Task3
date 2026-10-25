-- SD6103 Task 3 - Required analytical queries
-- PostgreSQL 18; schema names follow the supplied Chen ER diagram.
-- Tables: town, hdb_flat, resale_transaction, nearby,
--         hawker_centre, proximity_level.

SET search_path = housing, public;

-- Reusable classification view.  The three intervals are:
-- near [0,500), medium [500,1000), far [1000,2000].
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

-- Q1. Average price per square metre for 4-room and 5-room flats
-- in the 36-month window ending at the latest loaded month.
WITH bounds AS (
    SELECT date_trunc('month', max(sale_month))::date AS latest_month
    FROM resale_transaction
)
SELECT t.town_name,
       rt.flat_type,
       round(avg(rt.resale_price / NULLIF(rt.floor_area_sqm, 0)), 2)
           AS avg_price_per_sqm,
       count(*) AS transaction_count
FROM resale_transaction AS rt
JOIN hdb_flat AS f USING (flat_id)
JOIN town AS t USING (town_id)
CROSS JOIN bounds AS b
WHERE rt.flat_type IN ('4 ROOM', '5 ROOM')
  AND rt.sale_month >= b.latest_month - interval '35 months'
  AND rt.sale_month <  b.latest_month + interval '1 month'
GROUP BY t.town_name, rt.flat_type
ORDER BY avg_price_per_sqm DESC, t.town_name, rt.flat_type;

-- Q2. Remaining-lease buckets per town.
WITH bucketed AS (
    SELECT rt.*,
           CASE
               WHEN rt.remaining_lease_months < 600 THEN '< 50 years'
               WHEN rt.remaining_lease_months < 840 THEN '50-69 years'
               ELSE '70+ years'
           END AS lease_bucket
    FROM resale_transaction AS rt
)
SELECT t.town_name,
       b.lease_bucket,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY b.resale_price)::numeric, 2)
           AS median_resale_price,
       round(avg(b.resale_price / NULLIF(b.floor_area_sqm, 0)), 2)
           AS avg_price_per_sqm,
       count(*) AS transaction_volume
FROM bucketed AS b
JOIN hdb_flat AS f USING (flat_id)
JOIN town AS t USING (town_id)
GROUP BY t.town_name, b.lease_bucket
ORDER BY t.town_name,
         CASE b.lease_bucket
             WHEN '< 50 years' THEN 1
             WHEN '50-69 years' THEN 2
             ELSE 3
         END;

-- Q3. Ten towns with the largest mean 3-room floor area, followed by
-- the maximum 3-room resale price for every represented year.
WITH top_towns AS (
    SELECT f.town_id,
           avg(rt.floor_area_sqm) AS avg_floor_area_sqm
    FROM resale_transaction AS rt
    JOIN hdb_flat AS f USING (flat_id)
    WHERE rt.flat_type = '3 ROOM'
    GROUP BY f.town_id
    ORDER BY avg_floor_area_sqm DESC, f.town_id
    LIMIT 10
)
SELECT t.town_name,
       round(tt.avg_floor_area_sqm, 2) AS avg_floor_area_sqm,
       extract(year FROM rt.sale_month)::int AS sale_year,
       max(rt.resale_price) AS highest_resale_price
FROM top_towns AS tt
JOIN town AS t USING (town_id)
JOIN hdb_flat AS f USING (town_id)
JOIN resale_transaction AS rt USING (flat_id)
WHERE rt.flat_type = '3 ROOM'
GROUP BY t.town_name, tt.avg_floor_area_sqm, sale_year
ORDER BY tt.avg_floor_area_sqm DESC, t.town_name, sale_year;

-- Q4. Compare the closest and furthest proximity classes.
-- Each flat/block is classified only by its single nearest stored hawker,
-- preventing a transaction from being counted once per nearby hawker.
WITH nearest_hawker AS (
    SELECT DISTINCT ON (flat_id)
           flat_id, proximity_class, distance_m, hawker_id
    FROM v_nearby_classified
    ORDER BY flat_id, distance_m, hawker_id
), prices AS (
    SELECT t.town_name,
           rt.flat_type,
           avg(rt.resale_price) FILTER (WHERE nh.proximity_class = 'near') AS avg_near,
           avg(rt.resale_price) FILTER (WHERE nh.proximity_class = 'far')  AS avg_far
    FROM resale_transaction AS rt
    JOIN hdb_flat AS f USING (flat_id)
    JOIN town AS t USING (town_id)
    JOIN nearest_hawker AS nh USING (flat_id)
    GROUP BY t.town_name, rt.flat_type
)
SELECT town_name,
       flat_type,
       round(avg_near, 2) AS avg_price_near_hawker,
       round(avg_far, 2) AS avg_price_far_hawker,
       round((avg_near - avg_far) * 100 / NULLIF(avg_far, 0), 2)
           AS price_diff_percentage
FROM prices
WHERE avg_near IS NOT NULL
  AND avg_far IS NOT NULL
ORDER BY price_diff_percentage DESC, town_name, flat_type;

-- Q5. Town/band prices near hawkers with fresh-market stalls.
-- SGD 350,000 is used because SGD 200,000 is universal in the complete
-- 1990-2026 dataset.  De-duplication is per transaction and band.
WITH eligible AS (
    SELECT DISTINCT rt.transaction_id,
           t.town_name,
           p.proximity_class,
           rt.resale_price
    FROM resale_transaction AS rt
    JOIN hdb_flat AS f USING (flat_id)
    JOIN town AS t USING (town_id)
    JOIN v_nearby_classified AS p USING (flat_id)
    JOIN hawker_centre AS h USING (hawker_id)
    WHERE h.has_fresh_market IS TRUE
), grouped AS (
    SELECT town_name,
           proximity_class,
           avg(resale_price) AS avg_resale_price,
           count(*) AS transaction_count
    FROM eligible
    GROUP BY town_name, proximity_class
)
SELECT town_name,
       proximity_class,
       round(avg_resale_price, 2) AS avg_resale_price,
       transaction_count
FROM grouped
WHERE avg_resale_price > 350000
ORDER BY avg_resale_price DESC, town_name, proximity_class;

-- Q6 (additional). Join all six tables for a coverage audit.
-- DISTINCT removes repeated transaction-band-status rows caused by multiple
-- hawkers in the same group, so averages are transaction-weighted.
WITH all_table_rows AS (
    SELECT DISTINCT t.town_name,
           pl.level_name AS proximity_class,
           CASE
               WHEN h.has_fresh_market IS TRUE THEN 'yes'
               WHEN h.has_fresh_market IS FALSE THEN 'no'
               ELSE 'unknown'
           END AS market_status,
           f.flat_id,
           rt.transaction_id,
           rt.resale_price
    FROM town AS t
    JOIN hdb_flat AS f USING (town_id)
    JOIN resale_transaction AS rt USING (flat_id)
    JOIN nearby AS n USING (flat_id)
    JOIN hawker_centre AS h USING (hawker_id)
    JOIN proximity_level AS pl
      ON n.distance_m >= pl.min_distance_m
     AND (n.distance_m < pl.max_distance_m
          OR (pl.upper_inclusive AND n.distance_m <= pl.max_distance_m))
)
SELECT town_name,
       proximity_class,
       market_status,
       count(DISTINCT flat_id) AS distinct_flats,
       count(DISTINCT transaction_id) AS distinct_transactions,
       round(avg(resale_price), 2) AS avg_resale_price
FROM all_table_rows
GROUP BY town_name, proximity_class, market_status
ORDER BY town_name, proximity_class, market_status;
