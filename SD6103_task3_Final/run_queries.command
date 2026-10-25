#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
PSQL_BIN="/Library/PostgreSQL/18/bin/psql"
read -s "PGPASSWORD?请输入 PostgreSQL 用户 postgres 的密码（输入时不会显示）："
echo
export PGPASSWORD
trap 'unset PGPASSWORD' EXIT
"$PSQL_BIN" -h localhost -p 5432 -U postgres -d demo -v ON_ERROR_STOP=1 -f sql/04_queries.sql | tee query_output.txt
echo "Q1–Q6 已全部执行，文本结果保存在 query_output.txt。"
