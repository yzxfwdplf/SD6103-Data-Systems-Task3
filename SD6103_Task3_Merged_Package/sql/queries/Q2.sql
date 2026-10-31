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
