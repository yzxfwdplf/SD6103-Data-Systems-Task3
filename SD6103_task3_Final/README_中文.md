# SD6103 PostgreSQL 导入包（数据库：demo）

这套文件用于把 Task 3 的当前数据导入你截图中的 PostgreSQL 18 / `demo` 数据库。它会新建 `housing` schema，不会删除 `public` schema。

## 你现在只需要做什么

1. 保持 PostgreSQL 18 正常运行。
2. 双击本文件夹里的 `setup_demo.command`。如果 macOS 阻止打开，右键该文件并选择“打开”。
3. 输入 PostgreSQL 用户 `postgres` 的密码。输入密码时屏幕不会显示字符，这是正常现象。
4. 等待终端显示 `PASS: all expected row counts match` 和“导入完成”。大文件导入可能需要数分钟。
5. 回到 pgAdmin，右键 `demo`，选择 `Refresh`。展开 `Schemas > housing > Tables`，应看到六张表。

## 应出现的行数

| 表 | 行数 |
|---|---:|
| town | 26 |
| hdb_flat | 9,852 |
| resale_transaction | 976,441 |
| hawker_centre | 129 |
| proximity_level | 3 |
| nearby | 43,036 |

## 在 pgAdmin 里运行 Q1–Q6 并截图

1. 选中数据库 `demo`，打开 `Tools > Query Tool`。
2. 点击 Query Tool 工具栏的文件夹图标，打开 `sql/04_queries.sql`。
3. 每次选中一道查询（Q1、Q2……Q6）后点击执行按钮。
4. 截图时保留：左侧 `demo/housing`、上方 SQL、下方 `Data Output`、右下角执行时间。
5. 可以先运行 `sql/03_verify.sql`，把 `PASS` 和六张表行数作为导入证据截图。

`run_queries.command` 也能一次执行全部查询并保存文字结果，但报告截图建议仍在 pgAdmin 的 Query Tool 中完成。

## 性能测试

双击 `run_benchmark.command`。脚本会：

- 在五个数据规模上运行 Q1–Q6，每题重复五次，共 150 次未建索引测试；
- 在最大数据规模建立索引后，每题再重复五次，共 30 次；
- 生成 `benchmark_summary.csv` 和 `benchmark_output.txt`。

性能测试比普通查询耗时长，建议先完成导入和 Q1–Q6 截图，再单独运行。

## 重新导入

再次运行 `setup_demo.command` 会删除并重建 `housing` schema。它不会动 `public` schema，但会覆盖 `housing` 中已有内容。
