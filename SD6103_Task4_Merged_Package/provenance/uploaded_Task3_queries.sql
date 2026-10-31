-- =====================================================================
-- SD6103 | Task 3 — Analytical queries (aligned with the Chen ER model)
-- Relations: town, hdb_flat, resale_transaction, hawker_centre, nearby
-- proximity_class is a DERIVED attribute of the M:N relationship `nearby`;
-- it is computed in a view from distance_m and never stored.
-- =====================================================================
SET search_path = housing, public;

-- ---------------------------------------------------------------------
-- Derived-attribute view for `nearby`
-- near [0, 500) m, medium [500, 1000) m, far [1000, 2000] m.
-- nearby.distance_m is constrained to [0, 2000], so ELSE = far.
-- proximity_rank gives a natural sort order (near < medium < far).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW nearby_classified AS
SELECT n.flat_id,
       n.hawker_id,
       n.distance_m,
       CASE WHEN n.distance_m < 500  THEN 'near'
            WHEN n.distance_m < 1000 THEN 'medium'
            ELSE 'far' END                         AS proximity_class,
       CASE WHEN n.distance_m < 500  THEN 1
            WHEN n.distance_m < 1000 THEN 2
            ELSE 3 END                             AS proximity_rank
FROM nearby n;
-- ---------------------------------------------------------------------
-- Q1: Average price per m^2 for 4-room and 5-room flats, by town, for
--     sales in the fixed 3-year range 1997-01 to 1999-12. The range lies
--     in the initially loaded 1990-1999 file and stays unchanged as more
--     files are added. Half-open bounds on sale_month keep it index-friendly.
-- ---------------------------------------------------------------------
SELECT t.town_name,
       rt.flat_type,
       round(avg(rt.resale_price / rt.floor_area_sqm), 2) AS avg_price_per_sqm,
       count(*)                                           AS transaction_count
FROM resale_transaction rt
JOIN hdb_flat f USING (flat_id)
JOIN town t     USING (town_id)
WHERE rt.flat_type IN ('4 ROOM', '5 ROOM')
  AND rt.sale_month >= DATE '1997-01-01'
  AND rt.sale_month <  DATE '2000-01-01'
GROUP BY t.town_name, rt.flat_type
ORDER BY avg_price_per_sqm DESC, t.town_name, rt.flat_type;

-- ---------------------------------------------------------------------
-- Q2: Remaining-lease buckets (< 50, 50-69, 70+ years) per town:
--     median price, average price per m^2, transaction volume.
--     bucket_rank keeps buckets in logical (not alphabetical) order.
-- ---------------------------------------------------------------------
WITH bucketed AS (
    SELECT f.town_id,
           rt.resale_price,
           rt.floor_area_sqm,
           CASE WHEN rt.remaining_lease_months < 600 THEN 1   -- < 50 years
                WHEN rt.remaining_lease_months < 840 THEN 2   -- 50-69 years
                ELSE 3 END AS bucket_rank                     -- 70+ years
    FROM resale_transaction rt
    JOIN hdb_flat f USING (flat_id)
)
SELECT t.town_name,
       CASE b.bucket_rank WHEN 1 THEN '< 50 years'
                          WHEN 2 THEN '50-69 years'
                          ELSE '70+ years' END                            AS lease_bucket,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY b.resale_price)::numeric, 2)
                                                                          AS median_resale_price,
       round(avg(b.resale_price / b.floor_area_sqm), 2)                   AS avg_price_per_sqm,
       count(*)                                                           AS transaction_volume
FROM bucketed b
JOIN town t USING (town_id)
GROUP BY t.town_name, b.bucket_rank
ORDER BY t.town_name, b.bucket_rank;

-- ---------------------------------------------------------------------
-- Q3: Ten towns with the largest mean 3-room floor area; for each,
--     the highest 3-room resale price in every year.
-- ---------------------------------------------------------------------
WITH top_towns AS (
    SELECT f.town_id
    FROM resale_transaction rt
    JOIN hdb_flat f USING (flat_id)
    WHERE rt.flat_type = '3 ROOM'
    GROUP BY f.town_id
    ORDER BY avg(rt.floor_area_sqm) DESC, f.town_id
    LIMIT 10
)
SELECT t.town_name,
       EXTRACT(year FROM rt.sale_month)::int AS sale_year,
       max(rt.resale_price)                  AS highest_resale_price
FROM resale_transaction rt
JOIN hdb_flat f   USING (flat_id)
JOIN top_towns x  USING (town_id)
JOIN town t       USING (town_id)
WHERE rt.flat_type = '3 ROOM'
GROUP BY t.town_name, sale_year
ORDER BY t.town_name, sale_year;

-- ---------------------------------------------------------------------
-- Q4: Proximity effect. Each flat is classified ONCE by its nearest
--     hawker centre (so a transaction is never counted twice), then
--     near vs far average prices are compared per town and flat type.
--     Flats with no hawker within 2 km have no `nearby` row and are
--     excluded.
-- ---------------------------------------------------------------------
WITH nearest AS (
    SELECT DISTINCT ON (flat_id) flat_id, proximity_class
    FROM nearby_classified
    ORDER BY flat_id, distance_m, hawker_id
), prices AS (
    SELECT t.town_name,
           rt.flat_type,
           avg(rt.resale_price) FILTER (WHERE n.proximity_class = 'near') AS avg_near,
           avg(rt.resale_price) FILTER (WHERE n.proximity_class = 'far')  AS avg_far
    FROM resale_transaction rt
    JOIN hdb_flat f USING (flat_id)
    JOIN town t     USING (town_id)
    JOIN nearest n  USING (flat_id)
    GROUP BY t.town_name, rt.flat_type
)
SELECT town_name,
       flat_type,
       round(avg_near, 2)                                       AS avg_price_near_hawker,
       round(avg_far, 2)                                        AS avg_price_far_hawker,
       round((avg_near - avg_far) * 100 / NULLIF(avg_far, 0), 2) AS price_diff_percentage
FROM prices
WHERE avg_near IS NOT NULL
  AND avg_far  IS NOT NULL
ORDER BY price_diff_percentage DESC, town_name, flat_type;

-- ---------------------------------------------------------------------
-- Q5: Transactions linked to hawker centres WITH fresh-market stalls,
--     average price per town and proximity class, keeping only groups
--     whose average exceeds the budget of SGD 350,000 (SGD 200,000 would
--     return every eligible town on the complete 1990-2026 data).
--     DISTINCT ensures a transaction counts once per (town, class) even
--     if its block links to several fresh-market hawkers in that class.
-- ---------------------------------------------------------------------
WITH eligible AS (
    SELECT DISTINCT rt.transaction_id,
                    f.town_id,
                    nc.proximity_class,
                    nc.proximity_rank,
                    rt.resale_price
    FROM resale_transaction rt
    JOIN hdb_flat f            USING (flat_id)
    JOIN nearby_classified nc  USING (flat_id)
    JOIN hawker_centre h       USING (hawker_id)
    WHERE h.has_fresh_market IS TRUE
)
SELECT t.town_name,
       e.proximity_class,
       round(avg(e.resale_price), 2) AS avg_resale_price,
       count(*)                      AS transaction_count
FROM eligible e
JOIN town t USING (town_id)
GROUP BY t.town_name, e.proximity_class, e.proximity_rank
HAVING avg(e.resale_price) > 350000
ORDER BY avg_resale_price DESC, t.town_name, e.proximity_rank;

-- ---------------------------------------------------------------------
-- Q6 (additional, joins all five relations): coverage audit per town,
--     proximity class and fresh-market status (NULL reported as
--     'unknown'). Transactions are de-duplicated inside each group
--     before averaging, so a flat linked to several hawkers in the same
--     group does not inflate the average.
-- ---------------------------------------------------------------------
WITH linked AS (
    SELECT DISTINCT t.town_name,
                    nc.proximity_class,
                    nc.proximity_rank,
                    CASE h.has_fresh_market WHEN TRUE  THEN 'yes'
                                            WHEN FALSE THEN 'no'
                                            ELSE 'unknown' END AS fresh_market_status,
                    f.flat_id,
                    rt.transaction_id,
                    rt.resale_price
    FROM town t
    JOIN hdb_flat f            USING (town_id)
    JOIN resale_transaction rt USING (flat_id)
    JOIN nearby_classified nc  USING (flat_id)   -- view over `nearby`
    JOIN hawker_centre h       USING (hawker_id)
)
SELECT town_name,
       proximity_class,
       fresh_market_status,
       count(DISTINCT flat_id)        AS flat_count,
       count(DISTINCT transaction_id) AS transaction_count,
       round(avg(resale_price), 2)    AS avg_resale_price
FROM linked
GROUP BY town_name, proximity_class, proximity_rank, fresh_market_status
ORDER BY town_name, proximity_rank, fresh_market_status;
