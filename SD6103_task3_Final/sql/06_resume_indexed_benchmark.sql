\set ON_ERROR_STOP on
\timing on
SET search_path = housing, public;

-- The unindexed 150 observations are already present from the completed DO block.
-- Remove any partial indexed observations so this resume step is repeatable.
DELETE FROM benchmark_results WHERE indexed IS TRUE;
CALL run_task3_benchmark(5::smallint, 976441, true);

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
