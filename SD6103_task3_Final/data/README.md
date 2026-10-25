# Required data files

The prepared CSV files are distributed separately in `SD6103_PostgreSQL_Import_Package.zip` and are intentionally excluded from GitHub.

Place these files in this directory before running `setup_demo.command`:

| Filename | Expected rows |
|---|---:|
| `town.csv` | 26 |
| `hdb_flat.csv` | 9,852 |
| `resale_transaction.csv` | 976,441 |
| `hawker_centre.csv` | 129 |
| `nearby.csv` | 43,036 |

The required columns are defined by `sql/01_schema.sql` and the `\copy` statements in `sql/02_load_data.sql`.
