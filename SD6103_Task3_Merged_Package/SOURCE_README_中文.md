# SD6103：Task 3 融合版与 Task 4 实验

这份包融合了原有 2023–2025 Task 3、队友 GitHub 仓库，以及上传的 `Task3_queries (1).sql`。正文沿用此前确认的学术报告风格；SQL、Python、JavaScript 和启动脚本附有解释性注释。

## 先看哪些文件

- `report/SD6103_Merged_Task3_Task4.pdf`：完整 Task 3 + Task 4，可用于组内审核和整合。
- `report/SD6103_Task4.pdf`：单独的 Task 4，方便放进小组总报告。
- `SD6103_Task4_Results.xlsx`：公式计算的均值、样本标准差、变化比例、原始计时及可编辑柱状图。
- `sql/queries/Q1.sql` 至 `Q6.sql`：展示、执行、测试共同使用的最终查询。
- `sql/01_schema.sql`、`00_load_psql.sql`、`03_verify.sql`：建表、手工加载和检查。
- `sql/06_candidate_indexes.sql`：七组候选索引的 DDL 参考；实验脚本会逐组测试，不是一次全部建好。
- `sql/07_confirmed_indexes.sql`：本次 WASM 确认测试实际使用的三索引组合。
- `evidence/run/measurements_raw.csv`：390 次真实计时。
- `evidence/run/plans/`：每次计时对应的完整 EXPLAIN JSON。
- `evidence/run/independent_validation.json`：独立 pandas 核对结果。

## 这次具体改好了什么

1. **时间全部统一**：六条查询都使用 `2023-01-01 <= sale_month < 2026-01-01`，包含 36 个月和 78,670 笔交易。不是只修改 Q1。
2. **保留队友的距离分级表**：形成六个逻辑表，并增加区间不重叠约束。它是逻辑实现中的查询字典，不是擅自增加一个新的概念 ER 实体。
3. **防止重复计算房价**：Q5/Q6 先去重“地址／距离／市场状态”成员关系，再连接交易。一笔交易在同一组里只算一次。
4. **Q4 最近食阁更明确**：先在原始 nearby 表找最近中心，以 hawker_id 打破距离并列，再匹配距离分组，让排序索引有机会被使用。
5. **基准和索引测试更公平**：Task 3 只保留约束自带索引；Task 4 每次单独测试一组额外索引。两边用完全同一份 SQL，没有 COUNT 包装或省略计算。
6. **结果能核对、测试能追溯**：六条查询独立核对通过；每组索引后的完整结果与基准一致。每条计时记录带查询哈希，保留五次原始值、均值、样本标准差、实际索引使用和存储开销。
7. **启动更通用**：原生运行器不硬编码 PostgreSQL 18 的安装路径，不删除既有 housing schema；每次建一个新的独立 schema。

## 测量结果怎么理解

本次共执行 390 次计时：Task 3 为 150 次，七组候选索引为 210 次，最终组合确认测试为 30 次。每组每条查询另有不计入统计的预热与结果检查。

最终确认组合让 **Q3 平均用时从 43.31 ms 降至 31.54 ms，下降 27.16%**。Q5 小幅变快，Q1/Q2/Q4/Q6 在确认轮次变慢；六条均值相加用时增加约 2.60%。因此，不能说“加了索引后所有查询都更快”。以六条查询等权的几何平均比率看，结果约为 0.975；它与总耗时采用不同权重，不能混为同一个指标。

三索引组合中实际只有日期／房型索引被六条查询使用，另两个索引增加了开销。本次保留真实测过的组合，避免把三索引成绩冒充单索引成绩。上线前应在原生 PostgreSQL 对只保留实际有用索引的精简版本重新测量。

## 原生 PostgreSQL 复跑

需要先准备一个可连接的 PostgreSQL 数据库，以及 Python 3.10+。运行器会自动创建新的 `sd6103_日期_随机后缀` schema，不会删除同库中原有的小组数据。原生运行器在当前环境仅做语法检查，未声称已在真实服务器执行通过。

```bash
python3 -m venv .venv # 创建隔离的 Python 环境。
source .venv/bin/activate # 激活项目环境；Windows 使用对应的 activate 命令。
python -m pip install -r requirements.txt # 安装数据库连接和独立核对所需依赖。
export PGHOST=localhost # 指定 PostgreSQL 主机。
export PGDATABASE=demo # 指定已有的项目数据库。
export PGUSER=postgres # 指定本地数据库账户；密码建议使用 .pgpass。
python scripts/run_native.py --output evidence/native_run_01 # 在新的 schema 和空输出目录重跑完整实验。
python scripts/validate_results.py --run evidence/native_run_01 # 独立核对原生查询结果和全部计时摘要。
```

macOS 也可在终端运行 `bash Run_Native_Mac.command`，或赋予执行权限后双击。无现有密码配置时会隐藏输入密码；不会把密码写入代码。

原生与 WASM 会根据各自实际测量自动选择组合，原生结果不必与本次 WASM 选择一致。脚本不提供未经校验的半途恢复；失败后的目录保留，重跑请使用新目录。复跑后应以新证据重新生成表格和图表，不能将包内旧 WASM 图表改名充当原生结果。

## 复现本次实际 WASM 实验

```bash
npm ci # 安装锁定版本的 PostgreSQL/WASM 运行库。
node scripts/run_wasm.mjs evidence/wasm_run_02 # 在新的空目录复跑相同查询与索引实验。
python scripts/validate_results.py --run evidence/wasm_run_02 # 独立检查全部结果和统计。
```

如需手工使用 psql，请在项目根目录运行 `psql -f sql/00_load_psql.sql`。它要求不存在 housing schema，并一次加载完整 S5。它不会执行五阶段计时；完整实验请使用上述运行器。

## 仍需小组确认的提交事项

这次实测是 **PostgreSQL 18.6 / PGlite 0.5.10 的 WASM 环境**，不是伪装的本机 PostgreSQL 计时，结果图也不是 pgAdmin 截图。原生 PostgreSQL 和真实 pgAdmin 证据须由原生复跑补充。

项目原说明用五个历史源文件逐步增长数据；小组后来指定只用 2023–2025。当前五阶段采用这三年内的稳定哈希分区，且每阶段覆盖全部 36 个月。它不能自动等同于原五历史文件方案。提交前需确认老师接受这个调整及替代工具，或者补做原要求的历史文件实验。报告已明确披露，未虚构批准。

现有完整交易 CSV 是原范围包已经处理好的 2023–2025 数据，不把队友仓库 2026 年的记录混进来。坐标与食阁属性保留所提供的参考快照，不能当成每笔历史成交时点的设施状态。`data_manifest.json` 的 input_sha256 记录上游输入；包级文件哈希另见 `PACKAGE_SHA256.json`。

## Meeting 可以直接这样说

“我们把两边代码统一成同一个三年数据版本，修正了食阁连接可能让交易重复计权的问题，也统一了六条查询的计算口径。Task 4 已测了七组候选索引，每条查询都保留五次结果和执行计划。Q3 有明显改善，其他查询并不是加索引就更快。报告、Excel、代码和复跑入口都整理好了，接下来主要是在原生 PostgreSQL 补跑，并确认老师接受三年范围的分阶段方案。”
