---
name: adb-mysql-guide
description: |
  AnalyticDB MySQL 方言知识库 - DDL/DML/函数/数据类型/索引设计/性能优化/限制约束。
  触发词：AnalyticDB、ADB MySQL、DISTRIBUTED BY、CLUSTERED KEY、PARTITION BY VALUE、聚簇索引、分布键。
---

# AnalyticDB MySQL 方言知识库

> AnalyticDB for MySQL（简称 ADB MySQL）是阿里云自研的云原生实时数据仓库，高度兼容 MySQL 协议，专为 OLAP 分析优化。
> SQL 编写通用规范（命名/格式/反模式）见 [sql-standards.md](sql-standards.md)；MaxCompute 方言见 [maxcompute-guide.md](maxcompute-guide.md)。

## 目录

1. [概述](#概述)
2. [DDL 语法差异](#ddl-语法差异)
3. [索引设计指南](#索引设计指南analyticdb-mysql)
4. [DML 语法差异](#dml-语法差异)
5. [函数差异](#函数差异)
6. [数据类型差异](#数据类型差异)
7. [性能优化](#性能优化)
8. [限制与约束](#限制与约束)
9. [最佳实践](#最佳实践)
10. [与其他数据库对比](#与其他数据库对比)

---

## 概述

AnalyticDB for MySQL（简称ADB MySQL）是阿里云自研的云原生实时数据仓库，高度兼容MySQL协议和语法，专为OLAP分析场景优化。

**核心特点**：
- ✅ 高度兼容MySQL协议
- ✅ 分布式列存架构
- ✅ 支持实时写入和秒级查询
- ⚠️ 不支持事务（ACID）
- ⚠️ DDL语法与MySQL有差异

**适用场景**：OLAP 数仓分析（业务数据底座）。海量离线处理请用 MaxCompute。

---

## DDL 语法差异

### 1. 创建分布式表

```sql
-- ADB MySQL 分布式表创建语法
CREATE TABLE [IF NOT EXISTS] table_name (
    column_name data_type [NOT NULL] [DEFAULT default_value] [COMMENT '注释'],
    ...
    [PRIMARY KEY (pk_columns)]  -- 主键必须包含分区键
)
DISTRIBUTED BY HASH(column_name)  -- 分布键（必选）
[PARTITION BY VALUE(partition_expr)]  -- 分区策略（可选）
[PARTITIONS N]  -- 分区数量（可选）
[CLUSTERED KEY (col1, col2)]  -- 聚集索引（可选，ADB 支持多列 CLUSTERED KEY）
[COMMENT '表注释']
;

-- 示例：创建订单事实表
CREATE TABLE fct_orders (
    order_id BIGINT NOT NULL COMMENT '订单ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    order_time DATETIME NOT NULL COMMENT '订单时间',
    amount DECIMAL(18,2) COMMENT '金额',
    status VARCHAR(20) COMMENT '状态',
    PRIMARY KEY (order_id, order_time)  -- 主键必须包含分区键
)
DISTRIBUTED BY HASH(order_id)  -- 按订单ID分布
PARTITION BY VALUE(DATE_FORMAT(order_time, '%Y%m'))  -- 按月分区
PARTITIONS 12
COMMENT '订单事实表';
```

### 2. 分布键选择原则

| 原则 | 说明 | 示例 |
|------|------|------|
| 高基数 | 选择唯一值多的字段 | order_id, user_id |
| JOIN友好 | 选择常用于JOIN的字段 | user_id |
| 分布均匀 | 避免数据倾斜 | ❌ status（只有几个值） |

### 3. 分区策略

```sql
-- 按月分区（最常用）
PARTITION BY VALUE(DATE_FORMAT(order_time, '%Y%m'))
PARTITIONS 24  -- 保留2年

-- 按日分区（日志场景）
PARTITION BY VALUE(DATE_FORMAT(log_time, '%Y%m%d'))
PARTITIONS 90  -- 保留3个月

-- 按字段值分区
PARTITION BY VALUE(region_code)
```

> ⚠️ ADB **不支持** `PARTITION BY RANGE ... VALUES LESS THAN`（那是 MySQL/PG 语法），只能 `PARTITION BY VALUE(...)`。

### 4. 聚簇索引（ADB特有）

```sql
-- 创建聚簇索引，提升特定查询性能
-- ⚠️ ADB不支持独立CREATE CLUSTERED INDEX，必须内联定义或用ALTER TABLE
-- 内联方式（推荐）：
CREATE TABLE fct_orders (
    order_id BIGINT NOT NULL COMMENT '订单ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    order_time DATETIME NOT NULL COMMENT '订单时间',
    amount DECIMAL(18,2) COMMENT '金额',
    status VARCHAR(20) COMMENT '状态',
    PRIMARY KEY (order_id, order_time),
    CLUSTERED KEY idx_cluster_user_time(user_id, order_time)  -- 聚簇索引内联定义
)
DISTRIBUTED BY HASH(order_id)
PARTITION BY VALUE(DATE_FORMAT(order_time, '%Y%m'))
PARTITIONS 12
COMMENT '订单事实表';

-- ALTER TABLE方式（表已存在时）：
-- ALTER TABLE fct_orders ADD CLUSTERED KEY idx_cluster_user_time(user_id, order_time);

-- 适用场景：
-- 1. 高频查询模式固定
-- 2. 查询条件包含索引前缀字段
-- 3. 需要范围查询优化

-- 示例：以下查询会命中聚簇索引
SELECT * FROM fct_orders
WHERE user_id = 1001
  AND order_time >= '2024-01-01';
```

### 5. 二级索引

```sql
-- ⚠️ ADB不支持独立CREATE INDEX / CREATE FULLTEXT INDEX，必须内联定义或用ALTER TABLE

-- 内联方式（推荐）：在CREATE TABLE中定义
CREATE TABLE articles (
    id BIGINT NOT NULL,
    title VARCHAR(200),
    content TEXT,
    user_id BIGINT,
    PRIMARY KEY (id),
    FULLTEXT INDEX idx_title(title),        -- 全文索引：单列（多列全文需拆为多个单列索引）
    FULLTEXT INDEX idx_content(content),     -- 全文索引：单列
    INDEX idx_user_id(user_id)              -- 普通二级索引：单列
)
DISTRIBUTED BY HASH(id);

-- ALTER TABLE方式（表已存在时）：
-- ALTER TABLE fct_orders ADD INDEX idx_user_id(user_id);           -- 添加普通索引
-- ALTER TABLE articles ADD FULLTEXT INDEX idx_title(title);        -- 添加全文索引（单列）

-- 删除索引（通过ALTER TABLE）
ALTER TABLE fct_orders DROP INDEX idx_user_id;
```

---

## 索引设计指南（AnalyticDB MySQL）

> ADB 的索引模型与 MySQL/PostgreSQL 差异很大：**不支持复合索引**、**不支持独立的 CREATE INDEX 语句**、**不支持 UNIQUE INDEX**，所有索引必须在 CREATE TABLE 中内联定义。

### 索引类型

| 类型 | 关键字 | 说明 | 每表数量 |
|------|--------|------|---------|
| 主键索引 | `PRIMARY KEY` | 主键即唯一约束（ADB 无独立 UNIQUE KEY），必须包含分布键和分区键 | 1 |
| 普通索引 | `INDEX(col)` | 默认会为全表所有列自动建索引；一旦手动为某列建 INDEX，其他列不再自动建。**一个普通索引只能含一列** | 多个 |
| 聚集索引 | `CLUSTERED KEY(col)` | 决定分区内的物理存储排序，加速范围/等值查询，适合高频过滤列（如 user_id） | 仅 1 个 |
| 全文索引 | `FULLTEXT INDEX(col)` | VARCHAR 列的全文检索 | 多个 |

### 建表时内联索引（ADB 唯一建索引方式）

```sql
CREATE TABLE dwd_trade_order (
    order_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    dt DATE NOT NULL,
    amount DECIMAL(18,2),
    memo VARCHAR(200),
    PRIMARY KEY (order_id, dt),         -- 主键含分布键+分区键
    CLUSTERED KEY ck_user(user_id),     -- 聚集索引：user_id 连续存储，加速按用户过滤
    INDEX idx_memo(memo)                -- 手动为 memo 建索引（其他列不再自动建）
)
DISTRIBUTED BY HASH(order_id)
PARTITION BY VALUE(DATE_FORMAT(dt, '%Y%m')) LIFECYCLE 36;
```

### 索引设计原则（ADB）

1. **聚集索引选高频过滤列**：如 SaaS 场景按 user_id 查询，用 `CLUSTERED KEY(user_id)` 让同一用户数据连续存储。
2. **慎用手动 INDEX**：一旦为某列手动建 INDEX，ADB 不再为其他列自动建索引，可能漏掉其他查询的索引。通常依赖默认的全列自动索引即可。
3. **不可建复合索引**：`INDEX(col1, col2)` 会报错；多列查询依赖默认的全列索引或聚集索引。
4. **分布键/分区键优先**：JOIN 列作为分布键可避免数据重分布，比加索引更关键。

### 索引维护

```sql
-- ADB：查看表结构（含索引定义）
SHOW CREATE TABLE dwd_trade_order;

-- ADB：索引变更需通过 ALTER TABLE（不支持独立 CREATE INDEX）
ALTER TABLE dwd_trade_order DROP INDEX idx_memo;
ALTER TABLE dwd_trade_order ADD INDEX idx_memo(memo);

-- ADB：触发统计信息更新（影响优化器）
ANALYZE TABLE dwd_trade_order;
```

---

## DML 语法差异

### 1. INSERT语句

```sql
-- 标准INSERT（兼容MySQL）
INSERT INTO fct_orders (order_id, user_id, order_time, amount)
VALUES (1, 1001, '2024-01-01 10:00:00', 99.99);

-- 批量INSERT（推荐，每批5000-10000行）
INSERT INTO fct_orders VALUES
    (1, 1001, '2024-01-01 10:00:00', 99.99),
    (2, 1002, '2024-01-01 11:00:00', 199.99),
    (3, 1003, '2024-01-01 12:00:00', 299.99);

-- INSERT OVERWRITE（ADB特有，覆盖分区）
INSERT OVERWRITE TABLE fct_orders
PARTITION(DATE_FORMAT(order_time, '%Y%m')='202401')
SELECT * FROM source_orders WHERE order_time >= '2024-01-01';
```

### 2. UPDATE/DELETE

```sql
-- 语法兼容MySQL，但性能较低
UPDATE fct_orders SET status = 'completed' WHERE order_id = 1;
DELETE FROM fct_orders WHERE order_id = 1;

-- 性能建议：
-- 1. 尽量使用INSERT OVERWRITE替代大批量更新
-- 2. 小批量操作可以接受
-- 3. 大批量更新建议重建表
```

---

## 函数差异

### 日期函数

| 功能 | MySQL | ADB MySQL | 兼容性 |
|------|-------|-----------|--------|
| 当前日期 | `CURDATE()` | `CURRENT_DATE` / `CURDATE()` | ✅ |
| 当前时间 | `NOW()` | `NOW()` / `CURRENT_TIMESTAMP` | ✅ |
| 日期格式化 | `DATE_FORMAT(d,f)` | `DATE_FORMAT(d,f)` | ✅ |
| 日期加减 | `DATE_ADD(d,i)` | `DATE_ADD(d,i)` | ✅ |
| 日期差 | `DATEDIFF(d1,d2)` | `DATEDIFF(d1,d2)` | ✅ |
| 时间戳转换 | `FROM_UNIXTIME(t)` | `FROM_UNIXTIME(t)` | ✅ |

### 聚合函数

| 功能 | MySQL | ADB MySQL | 说明 |
|------|-------|-----------|------|
| 求和 | `SUM()` | `SUM()` | ✅ 兼容 |
| 计数 | `COUNT()` | `COUNT()` | ✅ 兼容 |
| 精确去重 | `COUNT(DISTINCT)` | `COUNT(DISTINCT)` | ✅ 兼容但慢 |
| 近似去重 | - | `APPROX_COUNT_DISTINCT()` | ⚡ ADB特有，快10倍+ |
| 百分位 | - | `PERCENTILE(col, p)` | ⚡ ADB特有 |

```sql
-- 近似去重示例（大数据量推荐）
SELECT
    APPROX_COUNT_DISTINCT(user_id) AS uv,  -- 近似UV
    COUNT(*) AS pv
FROM fct_orders
WHERE order_time >= '2024-01-01';

-- 百分位示例
SELECT
    PERCENTILE(amount, 0.5) AS median_amount,  -- 中位数
    PERCENTILE(amount, 0.95) AS p95_amount
FROM fct_orders;
```

### 窗口函数

ADB MySQL完整支持窗口函数：

```sql
-- ROW_NUMBER
SELECT
    order_id,
    user_id,
    amount,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY amount DESC) AS rank
FROM fct_orders;

-- LEAD / LAG
SELECT
    order_id,
    amount,
    LAG(amount, 1) OVER (ORDER BY order_time) AS prev_amount,
    LEAD(amount, 1) OVER (ORDER BY order_time) AS next_amount
FROM fct_orders;

-- 累计求和
SELECT
    order_id,
    amount,
    SUM(amount) OVER (ORDER BY order_time) AS cumulative_amount
FROM fct_orders;

-- 移动平均
SELECT
    order_id,
    amount,
    AVG(amount) OVER (
        ORDER BY order_time
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg
FROM fct_orders;
```

---

## 数据类型差异

| 类型 | MySQL | ADB MySQL | 说明 |
|------|-------|-----------|------|
| 整数 | INT, BIGINT | ✅ 支持 | 完全兼容 |
| 小数 | DECIMAL(p,s) | ✅ 支持 | p最大65 |
| 字符串 | VARCHAR(n) | ✅ 支持 | n最大65535 |
| 大文本 | LONGTEXT | ❌ 不支持 | 使用TEXT替代 |
| 二进制 | LONGBLOB | ❌ 不支持 | 使用BLOB替代 |
| 时间 | DATETIME | ✅ 支持 | 精度3位毫秒 |
| JSON | JSON | ✅ 支持 | 函数兼容 |
| 布尔 | BOOLEAN | ✅ 支持 | TINYINT(1) |

---

## 性能优化

### 1. 分区裁剪

```sql
-- ✅ 推荐：查询包含分区条件
SELECT * FROM fct_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '202401'  -- 分区裁剪
  AND user_id = 1001;

-- ❌ 避免：不带分区条件，全分区扫描
SELECT * FROM fct_orders WHERE user_id = 1001;
```

### 2. 聚簇索引优化

```sql
-- 场景：频繁按用户+时间查询
-- ⚠️ ADB不支持独立CREATE CLUSTERED INDEX，在CREATE TABLE中内联定义：
--   CLUSTERED KEY idx_cluster_user_time(user_id, order_time)
-- 或通过ALTER TABLE添加：
--   ALTER TABLE fct_orders ADD CLUSTERED KEY idx_cluster_user_time(user_id, order_time);

-- 效果：数据按索引顺序存储，查询性能提升
```

### 3. 近似计算优化

```sql
-- 大数据量去重，使用近似函数
SELECT APPROX_COUNT_DISTINCT(user_id) AS uv
FROM fct_orders
WHERE order_time >= '2024-01-01';
-- 性能提升10倍以上，误差<1%
```

---

## 限制与约束

### 不支持的功能

| 功能 | MySQL | ADB MySQL | 替代方案 |
|------|-------|-----------|---------|
| 事务 | ✅ ACID | ❌ 不支持 | 使用INSERT OVERWRITE |
| 外键 | ✅ 支持 | ✅ 支持（内核 3.1.10+） | ADB 外键仅用于 JOIN 消除优化，不做数据完整性校验，且不支持复合外键（多列）。详见 [官方文档](https://help.aliyun.com/zh/analyticdb/analyticdb-for-mysql/developer-reference/create-table) |
| 触发器 | ✅ 支持 | ❌ 不支持 | 使用ETL流程 |
| 存储过程 | ✅ 支持 | ❌ 不支持 | 使用外部脚本 |
| 自定义函数 | ✅ 支持 | ❌ 不支持 | 使用内置函数 |
| 临时表 | ✅ TEMPORARY | ❌ 不支持 | 创建普通表后删除 |

### 性能特点

| 操作 | 性能 | 建议 |
|------|------|------|
| 批量INSERT | ⚡ 极快 | 每批5000-10000行 |
| 单行INSERT | 🐢 较慢 | 避免使用 |
| UPDATE/DELETE | 🐢 较慢 | 使用INSERT OVERWRITE |
| 分析查询 | ⚡ 极快 | 列存优势 |
| 单点查询 | 🐢 较慢 | 使用聚簇索引优化 |

---

## 最佳实践

### 表设计

```sql
-- ✅ 推荐：大宽表设计（减少JOIN）
CREATE TABLE fct_order_detail (
    order_id BIGINT,
    order_time DATETIME,
    user_id BIGINT,
    user_name VARCHAR(100),     -- 冗余用户名
    city VARCHAR(50),           -- 冗余城市
    product_id BIGINT,
    product_name VARCHAR(200),  -- 冗余商品名
    category VARCHAR(50),       -- 冗余分类
    quantity INT,
    amount DECIMAL(18,2),
    PRIMARY KEY (order_id, order_time)
)
DISTRIBUTED BY HASH(order_id)
PARTITION BY VALUE(DATE_FORMAT(order_time, '%Y%m'))
PARTITIONS 12;

-- ❌ 避免：过度范式化，JOIN过多
```

### ETL流程

```sql
-- ✅ 推荐：INSERT OVERWRITE覆盖分区
INSERT OVERWRITE TABLE fct_orders
PARTITION(DATE_FORMAT(order_time, '%Y%m')='${bizdate}')
SELECT * FROM source_orders
WHERE DATE_FORMAT(order_time, '%Y%m')='${bizdate}';

-- ✅ 推荐：批量INSERT
INSERT INTO fct_orders VALUES
    (1, 1001, '2024-01-01', 99.99),
    (2, 1002, '2024-01-01', 199.99),
    ...;

-- ❌ 避免：单行INSERT循环
INSERT INTO fct_orders VALUES (1, ...);
INSERT INTO fct_orders VALUES (2, ...);
```

---

## 与其他数据库对比

> 本表仅供技术架构对比理解，**不代表本套件支持 MySQL/PostgreSQL/ClickHouse**。生产代码仅使用 AnalyticDB MySQL 和 MaxCompute。

| 特性 | MySQL | ADB MySQL | PostgreSQL | ClickHouse |
|------|-------|-----------|------------|------------|
| 架构 | 单机/主从 | 分布式 | 单机/主从 | 分布式 |
| 存储引擎 | InnoDB行存 | 列存 | Heap | MergeTree |
| 事务支持 | ✅ ACID | ❌ 不支持 | ✅ ACID | ❌ 有限 |
| 分布�� | - | DISTRIBUTED BY | - | ORDER BY |
| 分区表 | PARTITION BY RANGE | PARTITION BY VALUE | PARTITION BY RANGE | PARTITION BY |
| 聚簇索引 | 主键聚簇 | 可选CLUSTERED | 主键聚簇 | ORDER BY |
| 适用场景 | OLTP | OLAP | HTAP | OLAP |
| 兼容性 | 标准 | MySQL协议 | 标准 | SQL扩展 |

---

## 参考资料

- [阿里云 AnalyticDB for MySQL 官方文档](https://help.aliyun.com/product/190244.html)
- [ADB CREATE TABLE 官方文档](https://help.aliyun.com/zh/analyticdb/analyticdb-for-mysql/developer-reference/create-table)
