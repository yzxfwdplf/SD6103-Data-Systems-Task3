# Task 3 融合优化版

## 先看这里
- report/SD6103_Task3_Merged.pdf：从融合报告的 Task 3 原始 LaTeX 内容重新排版得到的独立报告，包含 Q1–Q6、结果、Insight 和性能图。
- sql/04_queries.sql：带注释的六条最终 SQL；sql/queries/ 中是逐条查询的权威版本。
- data/processed/：全部六张表的可导入 CSV、五阶段分片、月份统计和数据说明。
- evidence/run/measurements_raw.csv：Task 3 的 150 条原始计时。
- evidence/run/results/、plans/：五阶段基准查询的完整结果与执行计划。
- evidence/figures/：六条查询结果图及规模–耗时图。

## 使用
解压后在本包根目录操作。在不存在 housing schema 的数据库中运行：
```bash
psql -f sql/00_load_psql.sql
psql -f sql/04_queries.sql
```
加载脚本会创建新 housing schema，不会覆盖已有同名 schema。
使用 `python scripts/validate_results.py` 可独立核对本包结果和计时统计。

## 完整复跑与共同依赖
scripts/run_native.py、run_wasm.mjs、Run_Native_Mac.command 及相应 SQL 是融合版的共同复跑程序，保留原样；它们会连续执行 Task 3 与 Task 4，所以所需候选索引配置也一并保留。Task 3 基准阶段不会提前创建这些可选索引。本包整理的已测证据只包含 Task 3。完整复跑安装方式和命令见 SOURCE_README_中文.md；输出请选择新的空目录。

## 数据与测量口径
数据范围：2023-01-01 至 2025-12-31，36 个月，共 78,670 条交易。原始房价数据和设施坐标沿用此前融合包的已处理快照；本包包含运行所需 CSV，并不包含所有上游原始下载文件或一套新的采集程序。六条最终查询、数据及已有计时值均未改写。
已测环境为 PostgreSQL 18.6 / PGlite 0.5.10（WASM）；原生 PostgreSQL 复跑和 pgAdmin 截图尚未完成。五阶段采用三年数据内的稳定哈希分片，与课程原先五个历史源文件的方案不同。报告保留了这些说明。
provenance/ 中的旧 SQL 仅用于追溯，不作为最终可执行查询。
