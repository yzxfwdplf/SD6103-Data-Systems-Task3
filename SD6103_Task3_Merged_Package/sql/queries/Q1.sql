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
