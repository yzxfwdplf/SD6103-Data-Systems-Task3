SET search_path = housing, public; -- Use the merged scoped schema.

SELECT t.town_name, -- Identify the town.
       rt.flat_type, -- Separate 4 ROOM and 5 ROOM sales.
       round(avg(rt.resale_price/rt.floor_area_sqm),2) AS avg_price_per_sqm, -- Weight each sale equally.
       count(*) AS transaction_count -- Report the underlying sample size.
FROM resale_transaction rt -- Read the scoped transaction table.
JOIN hdb_flat f USING(flat_id) -- Attach the sale's address.
JOIN town t USING(town_id) -- Attach its town name.
WHERE rt.flat_type IN ('4 ROOM','5 ROOM') -- Keep the two required room types.
  AND rt.sale_month>=DATE '2023-01-01' -- Include January 2023 onward.
  AND rt.sale_month<DATE '2026-01-01' -- Include all of December 2025.
GROUP BY t.town_name,rt.flat_type -- Compute a mean for each town/type pair.
ORDER BY avg_price_per_sqm DESC,t.town_name,rt.flat_type; -- Rank groups deterministically.


WITH bucketed AS ( -- Assign each scoped sale to one remaining-lease bucket.
 SELECT f.town_id,rt.resale_price,rt.floor_area_sqm, -- Keep the values needed for aggregation.
  CASE WHEN rt.remaining_lease_months<600 THEN 1 -- Less than 50 years.
       WHEN rt.remaining_lease_months<840 THEN 2 -- At least 50 and less than 70 years.
       ELSE 3 END AS bucket_rank -- At least 70 years.
 FROM resale_transaction rt -- Read the shared three-year sample.
 JOIN hdb_flat f USING(flat_id) -- Attach the town identifier.
 WHERE rt.sale_month>=DATE '2023-01-01' -- Start the common period.
   AND rt.sale_month<DATE '2026-01-01' -- End after December 2025.
)
SELECT t.town_name, -- Name the town.
 CASE b.bucket_rank WHEN 1 THEN '< 50 years' -- Label the short-lease group.
                    WHEN 2 THEN '50 to < 70 years' -- Label the middle group.
                    ELSE '70+ years' END AS lease_bucket, -- Label the longest group.
 round(percentile_cont(0.5) WITHIN GROUP -- Use a continuous median.
  (ORDER BY b.resale_price)::numeric,2) AS median_resale_price, -- Report nominal SGD.
 round(avg(b.resale_price/b.floor_area_sqm),2) AS avg_price_per_sqm, -- Average per-sale ratios.
 count(*) AS transaction_volume -- Count each transaction once.
FROM bucketed b -- Aggregate the assigned buckets.
JOIN town t USING(town_id) -- Attach the town name.
GROUP BY t.town_name,b.bucket_rank -- Keep town and bucket populations separate.
ORDER BY t.town_name,b.bucket_rank; -- Use logical lease-bucket order.


WITH top_towns AS ( -- Rank towns using the same scoped 3 ROOM population.
 SELECT f.town_id,avg(rt.floor_area_sqm) AS avg_3room_floor_area_sqm -- Weight transaction observations.
 FROM resale_transaction rt -- Read in-period sales.
 JOIN hdb_flat f USING(flat_id) -- Attach the town identifier.
 WHERE rt.flat_type='3 ROOM' -- Rank only the required room type.
   AND rt.sale_month>=DATE '2023-01-01' -- Start the ranking period.
   AND rt.sale_month<DATE '2026-01-01' -- Include December 2025 in ranking.
 GROUP BY f.town_id -- Compute each town's mean area.
 ORDER BY avg_3room_floor_area_sqm DESC,f.town_id -- Break ties by a stable key.
 LIMIT 10 -- Keep exactly ten towns.
)
SELECT t.town_name, -- Identify each selected town.
 extract(year FROM rt.sale_month)::integer AS sale_year, -- Create calendar-year groups.
 round(x.avg_3room_floor_area_sqm,2) AS avg_3room_floor_area_sqm, -- Show why the town was selected.
 max(rt.resale_price) AS highest_resale_price -- Report the annual maximum for 3 ROOM.
FROM resale_transaction rt -- Read the scoped sale observations.
JOIN hdb_flat f USING(flat_id) -- Attach town membership.
JOIN top_towns x USING(town_id) -- Restrict to the ten selected towns.
JOIN town t USING(town_id) -- Attach town names.
WHERE rt.flat_type='3 ROOM' -- Keep the same type in the annual-maximum stage.
  AND rt.sale_month>=DATE '2023-01-01' -- Apply the same start in both stages.
  AND rt.sale_month<DATE '2026-01-01' -- Apply the same end in both stages.
GROUP BY t.town_name,sale_year,x.avg_3room_floor_area_sqm -- Keep each town/year separate.
ORDER BY x.avg_3room_floor_area_sqm DESC,t.town_name,sale_year; -- Present ranked towns and years.


WITH nearest AS ( -- Select one physical centre before attaching the band lookup.
 SELECT DISTINCT ON (flat_id) flat_id,hawker_id,distance_m -- Keep one nearest link per address.
 FROM nearby -- Read the original relationship instead of multiplying it by sales.
 ORDER BY flat_id,distance_m,hawker_id -- Match the useful B-tree order and break distance ties.
), prices AS ( -- Compare the same town and room type in the common date window.
 SELECT t.town_name,rt.flat_type, -- Define each comparison group.
  avg(rt.resale_price) FILTER (WHERE p.level_name='near') AS avg_near, -- Mean within 500 metres.
  avg(rt.resale_price) FILTER (WHERE p.level_name='far') AS avg_far -- Mean at 1,000-2,000 metres.
 FROM resale_transaction rt -- Read sale observations at transaction grain.
 JOIN hdb_flat f USING (flat_id) -- Attach the sale's block address.
 JOIN town t USING (town_id) -- Attach its town name.
 JOIN nearest n USING (flat_id) -- Count each covered sale only once.
 JOIN proximity_level p ON n.distance_m>=p.min_distance_m -- Include the lower band boundary.
  AND (n.distance_m<p.max_distance_m -- Exclude ordinary upper boundaries.
       OR (p.upper_inclusive AND n.distance_m<=p.max_distance_m)) -- Include the final 2 km endpoint.
 WHERE rt.sale_month>=DATE '2023-01-01' -- Start the agreed three-year analysis scope.
   AND rt.sale_month<DATE '2026-01-01' -- Include all of December 2025.
 GROUP BY t.town_name,rt.flat_type -- Preserve separate comparison populations.
)
SELECT town_name AS town,flat_type, -- Match the required five-column output schema.
 round(avg_near,2) AS avg_price_near_hawker, -- Display near prices in nominal SGD.
 round(avg_far,2) AS avg_price_far_hawker, -- Display far prices in nominal SGD.
 round((avg_near-avg_far)*100/NULLIF(avg_far,0),2) AS price_diff_percentage -- Use unrounded means.
FROM prices -- Read the already grouped comparison values.
WHERE avg_near IS NOT NULL AND avg_far IS NOT NULL -- Require both near and far observations.
ORDER BY price_diff_percentage DESC,town,flat_type; -- Present deterministic ranked differences.


WITH eligible AS ( -- Avoid giving extra weight to multiple fresh-market centres.
 SELECT DISTINCT nc.flat_id,nc.proximity_class,nc.proximity_rank -- One address/class membership.
 FROM nearby_classified nc -- Read classified address-centre links.
 JOIN hawker_centre h USING(hawker_id) -- Attach market-stall status.
 WHERE h.has_fresh_market IS TRUE -- Exclude confirmed no and unknown status.
)
SELECT t.town_name,e.proximity_class, -- Group by town and distance band.
 round(avg(rt.resale_price),2) AS avg_resale_price, -- Average each within-group sale once.
 count(*) AS transaction_count -- Report the within-group sample size.
FROM resale_transaction rt -- Read the three-year sale observations.
JOIN hdb_flat f USING(flat_id) -- Attach town membership.
JOIN town t USING(town_id) -- Attach town names.
JOIN eligible e USING(flat_id) -- Use deduplicated fresh-market memberships.
WHERE rt.sale_month>=DATE '2023-01-01' -- Start the common analysis window.
  AND rt.sale_month<DATE '2026-01-01' -- Include the end of December 2025.
GROUP BY t.town_name,e.proximity_class,e.proximity_rank -- Keep distance groups separate.
HAVING avg(rt.resale_price)>700000 -- Use one fixed SGD 700,000 budget at every size.
ORDER BY avg_resale_price DESC,t.town_name,e.proximity_rank; -- Rank passing groups.


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
