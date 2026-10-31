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
