#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

PSQL_BIN="/Library/PostgreSQL/18/bin/psql"
if [[ ! -x "$PSQL_BIN" ]]; then
  echo "找不到 PostgreSQL 18 的 psql：$PSQL_BIN"
  exit 1
fi

echo "即将重建 demo 数据库中的 housing schema。demo 里的其他 schema 不受影响。"
read -s "PGPASSWORD?请输入 PostgreSQL 用户 postgres 的密码（输入时不会显示）："
echo
export PGPASSWORD
trap 'unset PGPASSWORD' EXIT

"$PSQL_BIN" -h localhost -p 5432 -U postgres -d demo -v ON_ERROR_STOP=1 -f sql/01_schema.sql
"$PSQL_BIN" -h localhost -p 5432 -U postgres -d demo -v ON_ERROR_STOP=1 -f sql/02_load_data.sql
"$PSQL_BIN" -h localhost -p 5432 -U postgres -d demo -v ON_ERROR_STOP=1 -f sql/03_verify.sql | tee verification_output.txt

echo
echo "导入完成。请在 pgAdmin 中右键 demo > Refresh，然后展开 Schemas > housing。"
echo "核验记录已保存到 verification_output.txt。"
