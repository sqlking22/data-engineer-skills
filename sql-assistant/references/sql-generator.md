---
name: sql-generator
description: |
  SQL生成器 - 自然语言转高质量SQL代码，支持多数据库方言。
  当用户需要生成SQL查询、转换业务需求为SQL、编写复杂JOIN或窗口函数时触发。
  触发词：生成SQL、写个查询、帮我写SQL、自然语言转SQL。
argument: { description: "业务需求描述（包含数据库类型、查询目标、条件、分组、排序等）", required: true }
agent: general-purpose
allowed-tools: [Read, Grep, Glob, Edit, Write, Bash]
---

# SQL生成器

将自然语言业务需求转换为高质量、高性能的SQL代码。

## 工作流

1. **需求解析** - 提取数据库类型、查询目标、过滤条件、分组维度、排序要求
2. **Schema分析** - 如提供表结构，理解表关系和字段含义
3. **SQL构建** - 生成符合规范的SQL代码
4. **优化建议** - 提供索引建议和性能预期

## 输出规范

所有生成的SQL必须包含：
- 标准版本头注释
- CTE结构（复杂查询）
- 执行建议（索引、预期性能）
- 符合 sql-standards.md 规范

### 版本头模板

```sql
-- ============================================
-- 查询目的：[一句话描述]
-- 目标数据库：[数据库类型及版本]
-- 作者：AI Assistant
-- 生成时间：YYYY-MM-DD
-- ============================================
```

### 代码结构模板

```sql
-- 版本头

WITH
-- CTE分层（如需要）
cte_1 AS (...),
cte_2 AS (...)

-- 主查询
SELECT
    column1,
    column2,
    aggregate_function(column3) AS alias
FROM table_name
[JOIN ...]
[WHERE ...]
[GROUP BY ...]
[HAVING ...]
[ORDER BY ...]
[LIMIT ...];

-- 执行建议
-- 1. 建议索引：...
-- 2. 预计扫描行数：...
-- 3. 预期执行时间：...
```

## 数据库方言适配

> 本套件仅支持 **AnalyticDB MySQL** 和 **MaxCompute**，生成 SQL 前必须确认目标库。函数对照与方言差异详见 [sql-standards.md](sql-standards.md)、[adb-mysql-guide.md](adb-mysql-guide.md)、[maxcompute-guide.md](maxcompute-guide.md)。

### 阿里云 AnalyticDB for MySQL 特有
- 分布键：`DISTRIBUTED BY HASH(column)`（必选）
- 分区策略：`PARTITION BY VALUE(表达式)`
- 聚簇索引：`CLUSTERED KEY (columns)`
- 分区覆盖：`INSERT OVERWRITE TABLE ... PARTITION(...)`
- 近似去重：`APPROX_COUNT_DISTINCT(column)`
- 百分位：`PERCENTILE(column, p)`

## 生成原则

### 1. 可读性优先
- 使用CTE而非嵌套子查询
- 清晰的缩进和换行
- 表别名使用有意义缩写（o=orders, u=users）
- 复杂逻辑添加注释

### 2. 性能优化
- 避免 `SELECT *`
- WHERE条件使用索引友好写法
- 日期范围使用闭开区间 `[start, end)`
- JOIN顺序优化

### 3. 健壮性
- NULL值处理（`COALESCE()`，ADB 与 MaxCompute 均支持；MaxCompute 也可用 `NVL()`）
- 除零保护（`NULLIF()`）
- 字符串安全处理

### 4. 命名规范
- 表名：小写下划线（`user_orders`）
- 字段别名：小写下划线（`total_amount`）
- CTE名称：描述性名词（`monthly_sales`）

## 复杂查询策略

### 多阶段生成（适用于复杂需求）

如果需求复杂，主动建议分阶段：

```
用户：统计各品类用户的复购率和客单价趋势，计算同比环比

AI：这个查询较复杂，建议分阶段生成：
1. 先生成CTE结构设计
2. 然后生成第一层CTE（用户购买行为）
3. 再生成第二层CTE（复购计算）
4. 最后合并为完整查询

是否继续分阶段生成？
```

### CTE层级设计

```sql
WITH
-- 第1层：基础数据清洗
base_data AS (
    SELECT ... FROM ... WHERE ...
),

-- 第2层：中间计算
intermediate_calc AS (
    SELECT ... FROM base_data ...
),

-- 第3层：最终聚合
final_aggregate AS (
    SELECT ... FROM intermediate_calc ...
)

SELECT * FROM final_aggregate;
```

## 输入解析

从用户输入中提取：

| 要素 | 示例 |
|------|------|
| 数据库类型 | AnalyticDB MySQL、MaxCompute |
| 查询目标 | 销售额统计、用户增长、留存率 |
| 时间范围 | 过去30天、2024年Q1、最近一年 |
| 过滤条件 | 已完成订单、活跃用户、特定区域 |
| 分组维度 | 按品类、按区域、按日期 |
| 排序要求 | 按销售额降序、按日期升序 |
| 特殊要求 | 同比增长、累计计算、排名 |

## 当前需求

$ARGUMENTS

---

**生成SQL时**：
1. 首先确认理解的需求是否正确
2. 生成符合上述规范的SQL代码
3. 提供索引建议和性能预期
4. 如需求不明确，主动询问关键信息

---

## 阿里云 AnalyticDB for MySQL 生成指南

### 前置确认

【强制】ADB MySQL生成前检查：
- [ ] **确认数据库类型**
  - 提示：AnalyticDB for MySQL是阿里云数据仓库，与标准MySQL有差异
  - 区分：不是RDS MySQL，也不是标准MySQL
  - 问询：如用户只说MySQL，需确认是否是ADB MySQL

- [ ] **分布键选择**
  - 规则：选择高基数字段（如ID字段）
  - 推荐：order_id, user_id, log_id
  - 避免：低基数字段如status、region（数据倾斜）

- [ ] **分区策略确认**
  - 按月分区：`DATE_FORMAT(time_col, '%Y%m')`
  - 按日分区：`DATE_FORMAT(time_col, '%Y%m%d')`
  - 不分区：小表或维度表可以不分区

- [ ] **主键约束**
  - 规则：主键必须包含分区键
  - 示例：分区键是order_time，主键必须是(order_id, order_time)

- [ ] **查询场景确认**
  - OLAP分析查询 → 适合ADB（推荐）
  - OLTP事务查询 → 不适合ADB（建议用RDS MySQL）

### DDL生成模板

#### 分布式事实表模板

```sql
-- 模板：分布式事实表
-- ============================================
-- 表名：{table_name}
-- 用途：{用途描述}
-- 数据库：AnalyticDB for MySQL
-- 分布键：{dist_key}（选择高基数字段）
-- 分区策略：按{时间粒度}分区
-- ============================================

CREATE TABLE {table_name} (
    {pk_column} BIGINT NOT NULL COMMENT '{主键字段}',
    {time_column} DATETIME NOT NULL COMMENT '{时间字段，用于分区}',
    {dimension_columns},
    {measure_columns},
    PRIMARY KEY ({pk_column}, {time_column})  -- 主键必须包含分区键
)
DISTRIBUTED BY HASH({pk_column})  -- 分布键
PARTITION BY VALUE(DATE_FORMAT({time_column}, '%Y%m'))  -- 按月分区
PARTITIONS {partition_count}  -- 分区数量
COMMENT '{表注释}'
;

-- 建议索引：
-- 1. 如需按{常用查询字段}查询优化，可创建聚簇索引
-- 2. 如需按{筛选字段}过滤，可创建二级索引
```

#### 维度表模板

```sql
-- 模板：维度表（通常不需要分区）
CREATE TABLE dim_{dimension_name} (
    {id_column} BIGINT NOT NULL COMMENT '维度ID',
    {name_column} VARCHAR(100) COMMENT '名称',
    {attributes_columns},
    PRIMARY KEY ({id_column})
)
DISTRIBUTED BY HASH({id_column})
COMMENT '{维度表注释}'
;
```

#### 带聚簇索引的表模板

```sql
-- 模板：带聚簇索引（优化特定查询模式）
CREATE TABLE {table_name} (
    {columns}
)
DISTRIBUTED BY HASH({dist_key})
CLUSTERED KEY ({query_columns})  -- 聚集索引，按高频查询字段
PARTITION BY VALUE(DATE_FORMAT({time_col}, '%Y%m'))
PARTITIONS {n}
;

-- 聚簇索引适用场景：
-- 1. 高频查询模式：WHERE user_id = ? AND order_time >= ?
-- 2. 范围查询优化
-- 3. 减少IO扫描
```

### DML生成模板

#### 批量数据插入模板

```sql
-- 批量INSERT（推荐，每批5000-10000行）
INSERT INTO {table_name} (
    {column_list}
) VALUES
    ({row1_values}),
    ({row2_values}),
    ...
    ({rowN_values});
```

#### 分区覆盖写入模板

```sql
-- INSERT OVERWRITE（ETL场景，覆盖特定分区）
-- ============================================
-- 操作：覆盖{partition_value}分区数据
-- 场景：每日数据重新加载、数据修正
-- ============================================

INSERT OVERWRITE TABLE {table_name}
PARTITION(DATE_FORMAT({time_column}, '%Y%m') = '{partition_value}')
SELECT
    {column_list}
FROM {source_table}
WHERE DATE_FORMAT({time_column}, '%Y%m') = '{partition_value}'
  AND {additional_conditions}
;
```

### 查询生成优化

#### 分区裁剪优化（必须）

```sql
-- ✅ 生成的SQL必须包含分区条件（如适用）
SELECT {columns}
FROM {table_name}
WHERE DATE_FORMAT({time_column}, '%Y%m') = '{partition_value}'  -- 分区裁剪
  AND {other_conditions}
{GROUP BY ...}
{ORDER BY ...}
;

-- ❌ 避免生成不带分区条件的查询（除非维度表）
SELECT * FROM {table_name} WHERE {non_partition_condition};
-- 这会导致全分区扫描，性能极差
```

#### 近似计算优化

```sql
-- 大数据量去重统计，使用近似函数
SELECT
    APPROX_COUNT_DISTINCT({user_column}) AS uv,  -- 近似UV，性能提升10倍+
    COUNT(*) AS pv,
    SUM({amount_column}) AS total_amount
FROM {table_name}
WHERE DATE_FORMAT({time_column}, '%Y%m') = '{partition_value}'
;

-- 精确去重（数据量小时使用）
SELECT COUNT(DISTINCT {user_column}) AS uv  -- 小数据量可用
FROM {table_name}
WHERE ...
```

#### 聚簇索引利用

```sql
-- 聚簇索引命中示例
-- 表有聚簇索引：(user_id, order_time)
SELECT *
FROM fct_orders
WHERE user_id = 1001              -- 聚簇索引第一列
  AND order_time >= '2024-01-01'  -- 聚簇索引第二列（范围）
  AND status = 'completed'
ORDER BY order_time DESC
LIMIT 100;
```

### 生成示例

#### 示例1：生成事实表DDL

**用户输入**：
```
创建订单事实表，包含订单ID、用户ID、订单时间、商品ID、金额、状态
使用ADB MySQL，按订单ID分布，按月分区，保留1年数据
```

**生成的SQL**：
```sql
-- ============================================
-- 表名：fct_orders
-- 用途：订单事实表
-- 数据库：AnalyticDB for MySQL
-- 分布键：order_id（高基数，JOIN友好）
-- 分区策略：按月分区（便于分区裁剪）
-- 分区数量：12（保留1年数据）
-- ============================================

CREATE TABLE fct_orders (
    order_id BIGINT NOT NULL COMMENT '订单ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    order_time DATETIME NOT NULL COMMENT '订单时间',
    product_id BIGINT COMMENT '商品ID',
    amount DECIMAL(18,2) COMMENT '订单金额',
    status VARCHAR(20) COMMENT '订单状态',
    PRIMARY KEY (order_id, order_time)  -- 主键必须包含分区键order_time
)
DISTRIBUTED BY HASH(order_id)  -- 按订单ID分布，数据均匀
PARTITION BY VALUE(DATE_FORMAT(order_time, '%Y%m'))  -- 按月分区
PARTITIONS 12
COMMENT '订单事实表';

-- 索引建议（⚠️ ADB不支持独立CREATE INDEX/CLUSTERED INDEX，必须内联或ALTER TABLE）：
-- 1. 用户查询优化：
--    建表时内联：CLUSTERED KEY idx_cluster_user_time(user_id, order_time)
--    或事后添加：ALTER TABLE fct_orders ADD CLUSTERED KEY idx_cluster_user_time(user_id, order_time);
--    适用场景：按用户维度分析订单

-- 2. 状态筛选优化：
--    建表时内联：INDEX idx_status(status)
--    或事后添加：ALTER TABLE fct_orders ADD INDEX idx_status(status);
--    适用场景：按状态过滤订单

-- 性能预期：
-- - 写入性能：批量INSERT，约5万行/秒
-- - 查询性能：分区裁剪后，秒级响应
```

#### 示例2：生成分析查询

**用户输入**：
```
统计2024年1月各区域的销售额和订单量，按销售额降序
数据库：ADB MySQL，表名fct_orders
```

**生成的SQL**：
```sql
-- ============================================
-- 查询目的：各区域销售额和订单量统计
-- 目标数据库：AnalyticDB for MySQL
-- 优化策略：分区裁剪、近似计算
-- 生成时间：2024-03-15
-- ============================================

WITH regional_sales AS (
    SELECT
        region,
        SUM(amount) AS total_amount,
        COUNT(*) AS order_count,
        APPROX_COUNT_DISTINCT(user_id) AS buyer_count  -- 近似UV，性能优化
    FROM fct_orders
    WHERE DATE_FORMAT(order_time, '%Y%m') = '202401'  -- 分区裁剪，只扫描1个分区
      AND status = 'completed'
    GROUP BY region
)

SELECT
    region,
    total_amount,
    order_count,
    buyer_count,
    ROUND(total_amount / order_count, 2) AS avg_order_amount
FROM regional_sales
ORDER BY total_amount DESC;

-- 执行建议：
-- 1. ✅ 已使用分区裁剪：DATE_FORMAT(order_time, '%Y%m') = '202401'
--    效果：只扫描202401分区，避免全表扫描

-- 2. ✅ 已使用近似去重：APPROX_COUNT_DISTINCT(user_id)
--    效果：性能提升10倍+，误差<1%

-- 3. 建议索引（⚠️ ADB不支持独立CREATE INDEX）：
--    如region查询频繁，可内联定义 INDEX idx_region(region)，或通过 ALTER TABLE fct_orders ADD INDEX idx_region(region); 添加

-- 性能预期：
-- - 扫描数据量：约1个月数据，百万级
-- - 执行时间：预计1-3秒
```

#### 示例3：生成ETL语句

**用户输入**：
```
每日增量同步订单数据到ADB的fct_orders表
源表：source_orders，目标分区：${bizdate}
```

**生成的SQL**：
```sql
-- ============================================
-- ETL作业：订单数据日增量同步
-- 调度时间：每日凌晨02:00
-- 数据源：source_orders（业务库）
-- 目标表：fct_orders（ADB数仓）
-- 处理策略：分区覆盖（INSERT OVERWRITE）
-- ============================================

-- 覆盖写入目标分区
INSERT OVERWRITE TABLE fct_orders
PARTITION(DATE_FORMAT(order_time, '%Y%m') = '${bizdate}')
SELECT
    order_id,
    user_id,
    order_time,
    product_id,
    amount,
    status,
    CURRENT_TIMESTAMP AS etl_time
FROM source_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '${bizdate}';

-- 数据质量校验
SELECT
    '订单数量' AS metric_name,
    COUNT(*) AS metric_value,
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM fct_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '${bizdate}'

UNION ALL

SELECT
    '总金额' AS metric_name,
    SUM(amount) AS metric_value,
    CASE WHEN SUM(amount) > 0 THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM fct_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '${bizdate}';

-- 注意事项：
-- 1. 使用INSERT OVERWRITE而非UPDATE/DELETE
--    ADB是列存架构，UPDATE/DELETE性能较差

-- 2. 分区覆盖不影响历史数据
--    每日只覆盖当天分区，其他分区不受影响

-- 3. 执行前确保源表数据已就绪
--    建议在业务低峰期执行（凌晨）
```

### ADB MySQL特有语法速查

| 操作 | 语法 | 说明 |
|------|------|------|
| 创建分布表 | `DISTRIBUTED BY HASH(col)` | 必选 |
| 定义分区 | `PARTITION BY VALUE(expr)` | 可选 |
| 聚簇索引 | `CLUSTERED KEY (cols)` | 可选，性能优化 |
| 分区覆盖 | `INSERT OVERWRITE ... PARTITION(...)` | ETL常用 |
| 近似去重 | `APPROX_COUNT_DISTINCT(col)` | 大数据量优化 |
| 百分位 | `PERCENTILE(col, 0.5)` | 统计分析 |
