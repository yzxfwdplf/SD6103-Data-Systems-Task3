CREATE OR REPLACE VIEW nearby_classified AS -- Classify stored distances from the shared lookup.
SELECT n.flat_id,n.hawker_id,n.distance_m, -- Preserve each relationship key and exact distance.
 p.proximity_level_id,p.level_name AS proximity_class, -- Expose the configured band.
 p.proximity_level_id AS proximity_rank -- Keep near, medium and far in numeric order.
FROM nearby n -- Read one row per address-centre pair.
JOIN proximity_level p ON n.distance_m>=p.min_distance_m -- Include the lower boundary.
 AND (n.distance_m<p.max_distance_m -- Exclude ordinary upper boundaries.
      OR (p.upper_inclusive AND n.distance_m<=p.max_distance_m)); -- Include the final 2 km endpoint.
