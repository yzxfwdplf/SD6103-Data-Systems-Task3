SET search_path = housing, public;

SELECT
    t.town_name,
    rt.flat_type,
    ROUND(
        AVG(rt.resale_price / NULLIF(rt.floor_area_sqm, 0)),
        2
    ) AS avg_price_per_sqm,
    COUNT(*) AS transaction_count
FROM resale_transaction AS rt
JOIN hdb_flat AS f USING (flat_id)
JOIN town AS t USING (town_id)
WHERE rt.flat_type IN ('4 ROOM', '5 ROOM')
  AND rt.sale_month >= DATE '2023-01-01'
  AND rt.sale_month < DATE '2026-01-01'
GROUP BY
    t.town_name,
    rt.flat_type
ORDER BY
    avg_price_per_sqm DESC,
    t.town_name,
    rt.flat_type;
