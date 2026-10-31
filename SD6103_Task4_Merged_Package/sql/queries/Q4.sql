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
