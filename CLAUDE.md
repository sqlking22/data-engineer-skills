# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

数据开发工程师技能套件 — 一套 Claude Code Skill 工具集，覆盖从需求分析到数据测试的完整数据开发生命周期。专为数据团队设计，支持端到端数仓建设工作流。

**支持数据库**：AnalyticDB MySQL（数仓底座）、MaxCompute（大数据计算）。不再使用 MySQL、PostgreSQL、SQL Server、Oracle、Hologres。

**业务线**：PCB、PCBA、钢网、3D打印、元器件、CNC、FA、治具、软件服务、钣金、电热膜、手板复模、纸盒（国内+海外）。

## Architecture: Module Pipeline & Data Flow

6个独立模块通过标准化 YAML 包串联，形成管道式数据流：

```
requirement_package.yaml → modeling_package.yaml → sql_package.yaml → dq_package.yaml → test_package.yaml
```

每个包含 `version`、`metadata`、业务内容、`downstream_specs` 字段，供下游模块自动消费。完整联动配置见 `skill-connections.yaml`。

### 模块与命令速查

| 模块 | 入口 | 阶段命令 | 阶段Agent |
|------|------|----------|-----------|
| 需求分析 | `/requirement-analyst` | `/requirement-parser` → `/requirement-clarify` → `/requirement-transform` | general-purpose → Explore → general-purpose |
| 数据建模 | `/modeling-assistant` | `/model-design` → `/schema-doc` | general-purpose → general-purpose |
| SQL开发 | `/sql-assistant` | `/sql-gen` → `/sql-review` → `/sql-explain` | general-purpose → Explore → Explore |
| 数据质量 | `/dq-assistant` | `/dq-rule-gen` → `/dq-check` → `/dq-doc` | general-purpose → general-purpose → general-purpose |
| 数据测试 | `/test-engineer` | `/unit-test` → `/integration-test` → `/performance-test` | general-purpose → general-purpose → general-purpose |
| 数仓重构 | `/dw-refactor-assistant` | `/asset-inventory` → `/model-standardize` → `/lineage-scan` → `/dup-detection` → `/impact-analysis` → `/refactor-plan` → `/governance-setup` | 7阶段 |
| 联动中枢 | `/skill-hub` | 端到端编排 | general-purpose |

**快捷联动**：`--from-requirement`、`--from-model`、`--from-sql`、`--from-dq` 参数实现上游包自动注入。

## Key Technical Constraints

### ADB MySQL vs MaxCompute 方言差异（写SQL前必须确认目标库）

| 维度 | AnalyticDB MySQL | MaxCompute |
|------|-----------------|------------|
| 分布键 | `DISTRIBUTED BY HASH(col)` — 必须选高基数字段 | 自动分布 |
| 分区 | `PARTITION BY VALUE(col) LIFECYCLE n` — 保留 n 个分区 | 分区字段定义（`pt`/`dt`）+ `LIFECYCLE n`（天数，超期回收） |
| 主键 | 必须包含分布键和分区键 | 无主键约束 |
| 聚集索引 | `CLUSTERED KEY`（每个表仅1个，决定分区内的物理排序） | 不支持 |
| 条件函数 | `IF(cond, a, b)` / `CASE WHEN`（均支持） | `IF(cond, a, b)` / `CASE WHEN`（均支持，多分支用 CASE WHEN） |
| 日期函数 | `CURDATE()`, `NOW()`, `DATE_ADD(d, INTERVAL n DAY)` | `GETDATE()`, `DATEADD(d, n, 'dd')` |
| 分组连接 | `GROUP_CONCAT(col)` | `WM_CONCAT(col)` |
| 大表JOIN优化 | 分布键对齐 + `/*+ BROADCAST_JOIN(t) */` | `/*+ MAPJOIN(t) */`（小表放内存） |
| 分区裁剪 | WHERE 必须带分区列 | WHERE 必须带分区字段 |
| NULL 处理 | `COALESCE(a, b)` / `IFNULL` | `COALESCE(a, b)` / `NVL(a, b)` |

**ADB 关键限制（写 DDL 前必读）**：① 不支持唯一索引（`UNIQUE KEY`），靠主键保证唯一；② 不支持多列复合索引（`INDEX(col1,col2)`），一个普通索引只能含一列；③ 不支持 `UNSIGNED`；④ 不支持 `PARTITION BY RANGE ... VALUES LESS THAN`（那是 MySQL/PG 语法），只能 `PARTITION BY VALUE(...)`；⑤ 索引须**内联**在建表语句中，不支持独立的 `CREATE INDEX`；⑥ `AUTO_INCREMENT` 仅限 BIGINT，值非顺序递增；⑦ `FOREIGN KEY`（内核 3.1.10+）仅用于 JOIN 消除，不做完整性校验。详见 [ADB 官方 CREATE TABLE 文档](https://help.aliyun.com/zh/analyticdb/analyticdb-for-mysql/developer-reference/create-table)。

详细函数对照和性能优化 checklist：`sql-assistant/references/sql-standards.md`

### 数仓分层规范

```
ODS（贴源层） → DWD（明细层） → DWS（汇总层） → ADS（应用层）
                                DIM（维度层）
```

- 单向依赖：ADS → DWS → DWD → ODS，禁止反向依赖
- 命名：`{layer}_{domain}_{entity}`，字段 `snake_case`
- 事实表前缀 `fct_`，维度表前缀 `dim_`

### 建模方法论

- **自顶向下规划**：OneData — 数据域划分、总线矩阵、指标体系（`modeling-assistant/references/onedata-methodology.md`）
- **自底向上设计**：Kimball — 星型模型、事实表/维度表、SCD策略（`modeling-assistant/references/data-modeling-standards.md`）
- 默认 SCD Type 2（保留历史），维度表使用 BIGINT 代理键

### SQL 生成前置检查（强制）

1. 数据库类型已确认（ADB MySQL / MaxCompute），未指定必须询问
2. ADB 特有：确认分布键、分区策略、主键含分区键
3. 表结构信息已知
4. 查询目的明确：海量离线处理 → MaxCompute，OLAP 数仓分析 → ADB MySQL

## Module Reference Structure

每个模块遵循统一结构：

```
{module}/
├── SKILL.md          # 模块定义（frontmatter + 完整使用说明）
├── references/       # 规范文档（按需读取，不预热）
│   ├── best-practices.md    # 反模式、踩坑教训
│   └── *.md                 # 各功能参考
├── examples/         # 典型场景示例
└── scripts/          # 项目初始化脚本（init-project.sh）
```

**references 是按需读取的知识库**，不要在对话开始时全部加载。SKILL.md 中有参考资料导航表，根据用户当前任务阶段读取对应文件。

## Key Reference Files

| 用途 | 文件 |
|------|------|
| 联动配置 | `skill-connections.yaml` — 包格式规范、联动关系、工作流定义 |
| 联动中枢 | `skill-hub.md` — 完整工作流模板、上下文传递协议 |
| SQL规范 | `sql-assistant/references/sql-standards.md` — 命名、方言差异、优化checklist |
| SQL最佳实践 | `sql-assistant/references/best-practices.md` — 正反例、性能调优 |
| OneData方法论 | `modeling-assistant/references/onedata-methodology.md` |
| Kimball维度建模 | `modeling-assistant/references/data-modeling-standards.md` |
| 模型设计模板 | `modeling-assistant/references/model-design.md` |
| 质量标准 | `dq-assistant/references/data-quality-standards.md` |
| 测试标准 | `test-engineer/references/test-standards.md` |
| 重构方法论 | `dw-refactor-assistant/references/refactor-methodology.md` |
| 数仓规范 | `docs/数据仓库规范体系.md` — 团队数仓执行标准（行业方法论见同目录 `腾讯数据仓库规范体系.html`） |

## Scripts

| 脚本 | 用途 |
|------|------|
| `bash {module}/scripts/init-project.sh <dir> <name>` | 初始化模块项目骨架 |
| `bash dw-refactor-assistant/scripts/scan-tables.sh` | 扫描数仓资产 |
| `bash dw-refactor-assistant/scripts/check-naming.sh` | 检查命名规范 |
| `bash dw-refactor-assistant/scripts/detect-duplicates.sh` | 检测重复模型 |

## Working with This Repo

- 这是 Claude Code Skill 仓库，不是可编译/运行的应用。没有 build/test/lint 命令。
- 所有内容是 Markdown + YAML + Shell 脚本，为 Claude Code 提供 prompt 和参考知识。
- 修改模块时，确保同步更新 `skill-connections.yaml` 中的联动关系（如有新增包字段或联动路径）。
- 每个模块的 `SKILL.md` 是该模块的唯一入口定义，包含 frontmatter（name、description、触发词）和完整使用说明。