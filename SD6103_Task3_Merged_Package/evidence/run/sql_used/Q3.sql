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
