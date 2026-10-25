#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
PSQL_BIN="/Library/PostgreSQL/18/bin/psql"
read -s "PGPASSWORD?请输入 PostgreSQL 用户 postgres 的密码（输入时不会显示）："
echo
export PGPASSWORD
trap 'unset PGPASSWORD' EXIT
"$PSQL_BIN" -h localhost -p 5432 -U postgres -d demo -v ON_ERROR_STOP=1 -f sql/06_resume_indexed_benchmark.sql | tee benchmark_resume_output.txt
echo "性能测试完成：未建索引 150 次、建索引后 30 次。汇总见 benchmark_summary.csv。"
