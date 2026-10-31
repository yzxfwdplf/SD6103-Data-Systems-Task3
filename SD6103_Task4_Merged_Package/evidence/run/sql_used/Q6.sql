WITH membership AS ( -- Deduplicate small spatial memberships before joining transactions.
 SELECT DISTINCT n.flat_id,p.proximity_level_id AS proximity_rank, -- Keep one address/band key.
  p.level_name AS proximity_class, -- Use the teammate's shared band definitions.
  CASE h.has_fresh_market WHEN TRUE THEN 'yes' -- Preserve confirmed fresh-market access.
                          WHEN FALSE THEN 'no' -- Preserve confirmed absence.
                          ELSE 'unknown' END AS fresh_market_status -- Keep missing evidence separate.
 FROM nearby n -- Include the M:N relationship base relation.
 JOIN hawker_centre h USING (hawker_id) -- Include the centre base relation.
 JOIN proximity_level p ON n.distance_m>=p.min_distance_m -- Include the lookup base relation.
  AND (n.distance_m<p.max_distance_m -- Apply non-overlapping interval boundaries.
       OR (p.upper_inclusive AND n.distance_m<=p.max_distance_m)) -- Retain the inclusive last endpoint.
)
SELECT t.town_name,m.proximity_class,m.fresh_market_status, -- Define the reporting populations.
 count(DISTINCT f.flat_id) AS flat_count, -- Count participating block-address records.
 count(*) AS transaction_count, -- Count each sale once per unique membership group.
 round(avg(rt.resale_price),2) AS avg_resale_price -- Use the same population as the count.
FROM town t -- Include the town base relation.
JOIN hdb_flat f USING (town_id) -- Include the address base relation.
JOIN resale_transaction rt USING (flat_id) -- Include the sale base relation: six in total.
JOIN membership m USING (flat_id) -- Use deduplicated memberships, avoiding hawker fan-out.
WHERE rt.sale_month>=DATE '2023-01-01' -- Start the same period used by Q1-Q5.
  AND rt.sale_month<DATE '2026-01-01' -- Include all three complete calendar years.
GROUP BY t.town_name,m.proximity_class,m.proximity_rank,m.fresh_market_status -- Separate statuses.
ORDER BY t.town_name,m.proximity_rank,m.fresh_market_status; -- Preserve logical distance order.
