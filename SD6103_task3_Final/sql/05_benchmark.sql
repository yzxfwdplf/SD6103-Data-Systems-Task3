\set ON_ERROR_STOP on
\timing on
SET search_path = housing, public;

DROP TABLE IF EXISTS benchmark_transaction;
DROP TABLE IF EXISTS benchmark_results;
CREATE UNLOGGED TABLE benchmark_transaction
    (LIKE resale_transaction INCLUDING DEFAULTS INCLUDING CONSTRAINTS);
CREATE TABLE benchmark_results (
    size_level       smallint NOT NULL,
    transaction_rows integer NOT NULL,
    query_no         smallint NOT NULL,
    repetition       smallint NOT NULL,
    indexed          boolean NOT NULL,
    execution_ms     numeric(14,3) NOT NULL
);

CREATE OR REPLACE PROCEDURE run_task3_benchmark(p_size_level smallint, p_rows integer, p_indexed boolean)
LANGUAGE plpgsql
AS $$
DECLARE
    q text;
    q_no smallint;
    rep smallint;
    started_at timestamptz;
    queries text[] := ARRAY[
        $q$WITH bounds AS (SELECT date_trunc('month', max(sale_month))::date latest_month FROM benchmark_transaction)
           SELECT t.town_name, rt.flat_type, avg(rt.resale_price/NULLIF(rt.floor_area_sqm,0))
           FROM benchmark_transaction rt JOIN hdb_flat f USING(flat_id) JOIN town t USING(town_id) CROSS JOIN bounds b
           WHERE rt.flat_type IN ('4 ROOM','5 ROOM') AND rt.sale_month >= b.latest_month-interval '35 months'
             AND rt.sale_month < b.latest_month+interval '1 month' GROUP BY t.town_name, rt.flat_type$q$,
        $q$SELECT t.town_name,
             CASE WHEN rt.remaining_lease_months<600 THEN '< 50 years' WHEN rt.remaining_lease_months<840 THEN '50-69 years' ELSE '70+ years' END,
             percentile_cont(0.5) WITHIN GROUP (ORDER BY rt.resale_price), avg(rt.resale_price/NULLIF(rt.floor_area_sqm,0)), count(*)
           FROM benchmark_transaction rt JOIN hdb_flat f USING(flat_id) JOIN town t USING(town_id)
           GROUP BY t.town_name, 2$q$,
        $q$WITH top_towns AS (
             SELECT f.town_id, avg(rt.floor_area_sqm) a FROM benchmark_transaction rt JOIN hdb_flat f USING(flat_id)
             WHERE rt.flat_type='3 ROOM' GROUP BY f.town_id ORDER BY a DESC LIMIT 10)
           SELECT t.town_name, extract(year FROM rt.sale_month), max(rt.resale_price)
           FROM top_towns x JOIN town t USING(town_id) JOIN hdb_flat f USING(town_id)
             JOIN benchmark_transaction rt USING(flat_id) WHERE rt.flat_type='3 ROOM'
           GROUP BY t.town_name, extract(year FROM rt.sale_month)$q$,
        $q$WITH nearest AS (SELECT DISTINCT ON(flat_id) flat_id, proximity_class FROM v_nearby_classified ORDER BY flat_id,distance_m,hawker_id)
           SELECT t.town_name,rt.flat_type,
             avg(rt.resale_price) FILTER(WHERE n.proximity_class='near'),
             avg(rt.resale_price) FILTER(WHERE n.proximity_class='far')
           FROM benchmark_transaction rt JOIN hdb_flat f USING(flat_id) JOIN town t USING(town_id) JOIN nearest n USING(flat_id)
           GROUP BY t.town_name,rt.flat_type$q$,
        $q$SELECT t.town_name,x.proximity_class,avg(x.resale_price)
           FROM (SELECT DISTINCT rt.transaction_id,rt.flat_id,rt.resale_price,p.proximity_class
                 FROM benchmark_transaction rt JOIN v_nearby_classified p USING(flat_id)
                 JOIN hawker_centre h USING(hawker_id) WHERE h.has_fresh_market IS TRUE) x
           JOIN hdb_flat f USING(flat_id) JOIN town t USING(town_id) JOIN proximity_level p ON p.level_name=x.proximity_class
           GROUP BY t.town_name,x.proximity_class HAVING avg(x.resale_price)>350000$q$,
        $q$SELECT t.town_name,pl.level_name,
             CASE WHEN h.has_fresh_market IS TRUE THEN 'yes' WHEN h.has_fresh_market IS FALSE THEN 'no' ELSE 'unknown' END,
             count(DISTINCT f.flat_id),count(DISTINCT rt.transaction_id),avg(rt.resale_price)
           FROM town t JOIN hdb_flat f USING(town_id) JOIN benchmark_transaction rt USING(flat_id)
             JOIN nearby n USING(flat_id) JOIN hawker_centre h USING(hawker_id)
             JOIN proximity_level pl ON n.distance_m>=pl.min_distance_m AND (n.distance_m<pl.max_distance_m OR (pl.upper_inclusive AND n.distance_m<=pl.max_distance_m))
           GROUP BY t.town_name,pl.level_name,3$q$
    ];
BEGIN
    FOR q_no IN 1..array_length(queries, 1) LOOP
        q := queries[q_no];
        EXECUTE 'SELECT count(*) FROM (' || q || ') warmup';
        FOR rep IN 1..5 LOOP
            started_at := clock_timestamp();
            EXECUTE 'SELECT count(*) FROM (' || q || ') measured';
            INSERT INTO benchmark_results VALUES
                (p_size_level,p_rows,q_no,rep,p_indexed,
                 extract(epoch FROM clock_timestamp()-started_at)*1000);
        END LOOP;
    END LOOP;
END $$;

DO $$
DECLARE
    n integer;
    level_no smallint := 0;
BEGIN
    FOREACH n IN ARRAY ARRAY[278014,643914,696113,733266,976441] LOOP
        level_no := level_no + 1;
        TRUNCATE benchmark_transaction;
        INSERT INTO benchmark_transaction
        SELECT * FROM resale_transaction ORDER BY transaction_id LIMIT n;
        ANALYZE benchmark_transaction;
        CALL run_task3_benchmark(level_no,n,false);
    END LOOP;
END $$;

CREATE INDEX benchmark_month_type_idx ON benchmark_transaction(sale_month,flat_type);
CREATE INDEX benchmark_flat_idx ON benchmark_transaction(flat_id);
CREATE INDEX benchmark_lease_idx ON benchmark_transaction(remaining_lease_months);
ANALYZE benchmark_transaction;
CALL run_task3_benchmark(5::smallint,976441,true);

\copy (SELECT size_level,transaction_rows,query_no,indexed,round(avg(execution_ms),3) AS mean_ms,round(stddev_samp(execution_ms),3) AS sd_ms,min(execution_ms) AS min_ms,max(execution_ms) AS max_ms FROM benchmark_results GROUP BY size_level,transaction_rows,query_no,indexed ORDER BY indexed,size_level,query_no) TO 'benchmark_summary.csv' WITH (FORMAT csv, HEADER true)

SELECT indexed, count(*) AS observations
FROM benchmark_results
GROUP BY indexed
ORDER BY indexed;

SELECT size_level, transaction_rows, query_no, indexed,
       round(avg(execution_ms),3) AS mean_ms,
       round(stddev_samp(execution_ms),3) AS sd_ms
FROM benchmark_results
GROUP BY size_level, transaction_rows, query_no, indexed
ORDER BY indexed, size_level, query_no;
