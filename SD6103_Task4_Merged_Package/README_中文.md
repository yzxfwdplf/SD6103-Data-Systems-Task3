# Task 4 索引实验完整包

## 先看这里
- report/SD6103_Task4.pdf：独立 Task 4 报告。
- SD6103_Task4_Results.xlsx：原始计时、均值、变化比例及可编辑柱状图。
- sql/06_candidate_indexes.sql：七组候选索引及注释。
- sql/07_confirmed_indexes.sql：本次确认实验实际使用的索引组合。
- evidence/run/：全部 390 条计时、执行计划、结果一致性核对和索引选择记录。
- evidence/figures/Task4_comparison.png：索引前后耗时对比。
- data/processed/ 与 sql/queries/：与 Task 3 完全相同的数据、表结构和最终查询，支持单独解压复跑。

## 数据与计时
数据范围为 2023-01-01 至 2025-12-31，共 78,670 条交易。
measurements_raw.csv 保留 150 条 Task 3 基准、210 条候选索引测试及 30 条最终确认测试。Task4_measurements_raw.csv 另单列最大数据集的 30 条基准和 240 条索引测试，便于直接查看 Task 4。
报告保留真实的正面及负面结果：Q3 在确认测试中明显加速，但六条查询均值相加的总耗时增加约 2.60%，不能写成所有查询都加速。

## 复跑
安装方式和命令见 SOURCE_README_中文.md。完整运行器会先执行五阶段 Task 3 基准，再做候选索引及确认实验，以确保比较一致。输出请选择新的空目录。使用 `python scripts/validate_results.py` 可独立核对已有结果和计时。
本包同时保留合并报告和报告源文件，方便小组整合。

## 现有证据的边界
已测环境为 PostgreSQL 18.6 / PGlite 0.5.10（WASM）；原生 PostgreSQL 复跑和 pgAdmin 截图尚未完成。三年数据内的五阶段哈希分片与课程原先五个历史源文件方案不同。相关说明保留于报告中。
CSV 为此前融合包的已处理快照，不包含所有上游原始下载文件或一套新的采集程序。provenance/ 中旧 SQL 仅用于追溯，最终查询以 sql/queries/ 为准。
