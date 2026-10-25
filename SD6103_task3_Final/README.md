# SD6103 Data Systems Project - Task 3

This repository contains the final PostgreSQL code, verified results, and report for the SD6103 Data Systems Project Task 3.

The SQL and launcher scripts in this repository are copied unchanged from the final package that produced the verified PostgreSQL 18 results on 24 October 2026. The benchmark parameter-type correction is already included in `sql/05_benchmark.sql`.

## Repository contents

```text
.
├── README.md
├── README_中文.md
├── manifest.txt
├── SD6103_Task3_Queries.sql
├── setup_demo.command
├── run_queries.command
├── run_benchmark.command
├── resume_benchmark.command
├── data/
│   └── README.md
├── docs/
│   └── SD6103_Task3_Completed_Final_Verified.pdf
├── results/
│   ├── benchmark_summary.csv
│   └── benchmark_resume_output.txt
└── sql/
    ├── 01_schema.sql
    ├── 02_load_data.sql
    ├── 03_verify.sql
    ├── 04_queries.sql
    ├── 05_benchmark.sql
    └── 06_resume_indexed_benchmark.sql
```

## Data availability

The large CSV files are not committed to GitHub. Group members should obtain `SD6103_PostgreSQL_Import_Package.zip` from the group file area, or copy the five prepared CSV files into `data/` as described in `data/README.md`.

This separation keeps the GitHub repository suitable for code collaboration while the complete data package remains available for exact reproduction.

## Requirements

- PostgreSQL 18
- pgAdmin 4 or `psql`
- macOS for the supplied `.command` launchers
- Database: `demo`
- PostgreSQL user: `postgres`

The `.command` launchers use `/Library/PostgreSQL/18/bin/psql`, matching the environment used for the verified run. Users with a different installation path can execute the SQL files manually in pgAdmin in the order listed below.

## Reproduction steps

1. Place the five prepared CSV files in `data/`.
2. Run `setup_demo.command` and wait for:

   ```text
   PASS: all expected row counts match
   ```

3. Run `run_queries.command` to execute Q1-Q6.
4. Run `run_benchmark.command` to perform the full benchmark.
5. Use `resume_benchmark.command` only if an indexed benchmark run was interrupted after the 150 baseline observations had completed.

The same SQL can be run manually through pgAdmin Query Tool:

```text
01_schema.sql
02_load_data.sql
03_verify.sql
04_queries.sql
05_benchmark.sql
```

## Verified database snapshot

| Item | Verified value |
|---|---:|
| Raw HDB resale rows | 989,379 |
| Matched resale transactions | 976,441 |
| Towns | 26 |
| HDB flat/block records | 9,852 |
| Hawker centres | 129 |
| Nearby links | 43,036 |
| Latest month | 2026-10 |

## Verified query outputs

| Query | Output |
|---|---:|
| Q1 | 52 groups |
| Q2 | 64 groups |
| Q3 | 369 rows |
| Q4 | 75 groups |
| Q5 | 17 groups across 9 towns |
| Q6 | 154 groups |

## Performance benchmark

The verified benchmark contains 180 measured observations:

- 150 baseline observations: five data sizes x six queries x five repetitions.
- 30 observations after adding the benchmark's extra analytical indexes: six queries x five repetitions on the complete transaction snapshot.

“Baseline” does not mean that the database had no primary-key or integrity indexes. It means that the additional analytical indexes evaluated by the experiment had not yet been added to the benchmark transaction table.

The verified timing summary is available in `results/benchmark_summary.csv`.

## Collaboration workflow

Group members should create a branch for changes and submit a pull request instead of editing `main` directly. Do not commit raw CSV files, passwords, generated terminal histories, or local machine paths.

## Scope note

Q1 uses the required rolling 36-month window. Q2-Q5 use the complete matched transaction history. Q6 is an additional all-table coverage audit. Results are descriptive and should not be interpreted causally.
