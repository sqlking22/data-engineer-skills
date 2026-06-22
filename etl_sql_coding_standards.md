---
name: etl-sql-coding-standards
description: |
  ETL SQL 编码规范总入口 - 供 /review-sql 等审查命令作为合规判定的规范来源。
  本文件是规范门户，详细内容按主题拆分在 sql-assistant/references/ 下。
  触发词：ETL SQL 规范、SQL 审查标准、编码规范、review-sql、代码合规。
---

# ETL SQL 编码规范

> 本文件是 ETL SQL 编码合规判定的**总入口**，供 `/review-sql` 等审查命令读取。SQL 规范按主题分散在 `sql-assistant/references/` 下，按需读取对应文件。

## 规范文件导航

| 主题 | 文件 | 何时读 |
|------|------|--------|
| 通用规范（命名/格式/注释/反模式速查/性能 checklist） | [sql-assistant/references/sql-standards.md](sql-assistant/references/sql-standards.md) | 写/审任何 SQL |
| 反模式详解与踩坑教训（正反例） | [sql-assistant/references/best-practices.md](sql-assistant/references/best-practices.md) | 审查 SQL 质量 |
| AnalyticDB MySQL 方言（DDL/DML/函数/索引/限制） | [sql-assistant/references/adb-mysql-guide.md](sql-assistant/references/adb-mysql-guide.md) | ADB SQL |
| MaxCompute 方言（DDL/DML/MAPJOIN/分区） | [sql-assistant/references/maxcompute-guide.md](sql-assistant/references/maxcompute-guide.md) | MaxCompute SQL |

---

## ETL SQL 合规审查清单（/review-sql 判定依据）

### A. 文件命名
- 文件名遵循 `{table_name}_{granularity}_{refresh}.sql`（粒度 mf/df/di/hf/hi）
- 分层前缀正确：`ods_` / `dwd_` / `dim_` / `dws_` / `ads_`

### B. 头部元数据块
- 以 `-- ***...***` 分隔的头部块存在
- 需求来源（JLCD 工单号）已填（非 XXXXXX 占位）+ 任务跟踪 URL
- 所属业务线 / 数仓主题 / 模型名称 / 功能描述 已填
- 创建者 / 创建日期 / 调度频率 / 修改日志（至少一条）已填
- 输入表清单 / 输出表清单 已列

### C. 关键字与函数大小写
- 保留字大写（SELECT/FROM/WHERE/JOIN/GROUP BY/ORDER BY/INSERT/WITH/AS/ON/AND/CASE WHEN 等）
- 函数名大写（COUNT/SUM/MAX/MIN/IFNULL/COALESCE/CAST/ROW_NUMBER/DATE_FORMAT 等）
- 数据类型大写（BIGINT/VARCHAR/DECIMAL/DATE/DATETIME 等）
- 标识符 snake_case 小写

### D. 缩进与格式
- 2 空格缩进，无 Tab；行宽 ≤ 120
- SELECT 一字段一行；逗号风格统一（行首或行尾）
- WHERE 一条件一行，AND/OR 缩进；JOIN ON 缩进对齐
- 子查询/CTE 相对外层缩进

### E. JOIN 规范
- 显式 JOIN 类型（INNER/LEFT/RIGHT/FULL/CROSS）
- 禁止隐式逗号 JOIN（`FROM a, b WHERE`）
- 每个 JOIN 都有 ON

### F. 别名规范
- 列别名用 `AS`；表别名简短有意义（2-4 字符）
- CTE 命名描述性（禁用 cte1/a/b）
- 列别名遵循后缀约定（_id/_count/_flag/_rate/_date 等）

### G. 注释规范
- 复杂 CTE 有编号头注释；大段逻辑有 `-- ===` 分隔符
- 公式、映射、魔法值有行内注释；注释解释"为什么"
- DDL 段（CREATE TABLE）存在（可注释态）

### H. 代码结构
- 优先 CTE 而非嵌套子查询；每个 CTE 单一职责
- 顺序：头部 → 配置 → DDL → ETL → 数据质量校验

### I. GROUP BY
- 用显式列名，不用位置序号（`GROUP BY 1,2`）

### J. 数据质量校验
- 文件末尾有（注释态）DQ 校验 SQL：行数、空值率、维度分布、同环比

---

## 方言前置确认（写/审 SQL 前必做）

- **目标库已确认**：AnalyticDB MySQL 还是 MaxCompute？未确认必须先问。
- **ADB 特有检查**：分布键（`DISTRIBUTED BY HASH`）选择、分区策略（`PARTITION BY VALUE`）、主键含分区键、禁用复合索引/UNIQUE KEY/`ON UPDATE CURRENT_TIMESTAMP`
- **MaxCompute 特有检查**：WHERE 带分区字段、小表用 `/*+ MAPJOIN(t) */`

> 方言详细差异与函数对照见上方导航表的两个 guide 文件。

---

## 参考资料

- [AnalyticDB MySQL 官方文档](https://help.aliyun.com/product/190244.html)
- [ADB CREATE TABLE 文档](https://help.aliyun.com/zh/analyticdb/analyticdb-for-mysql/developer-reference/create-table)
- [MaxCompute 官方文档](https://help.aliyun.com/product/27748.html)
