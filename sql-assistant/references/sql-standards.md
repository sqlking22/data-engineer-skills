# SQL 开发规范与标准参考

## 目录

1. [SQL 编写规范](#sql-编写规范)
2. [数据库方言差异](#数据库方言差异)
3. [性能优化 checklist](#性能优化-checklist)
4. [常见反模式](#常见反模式)
5. [索引设计指南](#索引设计指南)

---

## SQL 编写规范

### 命名规范

| 对象 | 规范 | 示例 |
|------|------|------|
| 表名 | 小写下划线，复数形式 | `user_orders`, `product_categories` |
| 字段名 | 小写下划线 | `created_at`, `total_amount` |
| 索引名 | `idx_` + 表名 + 字段名 | `idx_orders_user_id` |
| 约束名 | `pk_`, `fk_`, `uq_` 前缀 | `pk_orders`, `fk_orders_user_id` |
| CTE名称 | 描述性名词 | `monthly_sales`, `active_users` |
| 临时表 | `tmp_` + 描述 + 日期 | `tmp_order_stats_20240317` |

### 代码格式

```sql
-- ✅ 推荐格式
SELECT
    o.order_id,o.user_id,
    u.username,
    SUM(oi.amount) AS total_amount
FROM orders o
INNER JOIN users u ON o.user_id = u.id
INNER JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.created_at >= '2024-01-01'
    AND o.status = 'completed'
GROUP BY o.order_id, o.user_id, u.username
HAVING SUM(oi.amount) > 1000
ORDER BY total_amount DESC
LIMIT 100;

-- ❌ 避免
select o.order_id, o.user_id, u.username, sum(oi.amount) as total_amount from orders o
inner join users u on o.user_id=u.id
inner join order_items oi on o.order_id=oi.order_id
where o.created_at>='2024-01-01' and o.status='completed'
group by o.order_id, o.user_id, u.username having sum(oi.amount)>1000
order by total_amount desc limit 100;
```

### 注释规范

```sql
-- ============================================
-- 查询目的：统计月度活跃用户
-- 业务场景：运营报表
-- 更新历史：
--   2024-03-01: 增加渠道筛选条件 (by zhangsan)
-- ============================================

/*
 * 临时解决方案：等待用户行为表分区改造完成后优化
 * TODO: 2024-06-01 前完成优化
 */
```

---

## ADB MySQL 与 MaxCompute 函数速查

### 常用函数对照

| 功能 | AnalyticDB MySQL | MaxCompute | 说明 |
|------|-----------------|------------|------|
| 当前日期 | `CURDATE()` / `CURRENT_DATE` | `GETDATE()` | |
| 当前时间戳 | `NOW()` | `GETDATE()` | |
| 日期格式化 | `DATE_FORMAT(d,f)` | `DATE_FORMAT(d,f)` | 格式串兼容 |
| 日期加减 | `DATE_ADD(d, INTERVAL n DAY)` | `DATEADD(d, n, 'dd')` | |
| 日期差 | `DATEDIFF(d1,d2)` | `DATEDIFF(d1, d2)` | |
| 字符串拼接 | `CONCAT(s1, s2)` | `CONCAT(s1, s2)` | |
| 条件判断 | `IF(cond, a, b)` | `IF(cond, a, b)` / `CASE WHEN` | 两者均支持 IF；多分支用 CASE WHEN |
| 类型转换 | `CAST(expr AS type)` | `CAST(expr AS type)` | |
| 去重计数 | `COUNT(DISTINCT col)` | `COUNT(DISTINCT col)` | |
| 近似去重 | `APPROX_COUNT_DISTINCT(col)` | - | ADB 特有，性能快 10 倍+ |
| 百分位 | `PERCENTILE(col, p)` | - | ADB 特有 |
| 分组连接 | `GROUP_CONCAT(col)` | `WM_CONCAT(col)` | |

---

## 性能优化 checklist

### 查询前检查

- [ ] 是否只查询需要的字段（避免 SELECT *）
- [ ] WHERE 条件是否使用了索引字段
- [ ] 日期范围是否使用闭开区间 `[start, end)`
- [ ] 大表查询是否添加了 LIMIT
- [ ] 是否可以使用覆盖索引

### JOIN 检查

- [ ] JOIN 条件是否完整（避免笛卡尔积）
- [ ] JOIN 字段是否有索引
- [ ] 小表是否作为驱动表
- [ ] 是否有多余的 JOIN

### 聚合检查

- [ ] GROUP BY 字段是否最小化
- [ ] HAVING 是否可以改为 WHERE
- [ ] 是否可以使用 ROLLUP/CUBE 替代多个查询

### 子查询检查

- [ ] 关联子查询是否可以改为 JOIN
- [ ] IN 子查询是否可以改为 EXISTS（大数据量时）
- [ ] 是否可以改为 CTE 提高可读性

---

## 常见反模式

### 反模式 1：SELECT *

```sql
-- ❌ 低效
SELECT * FROM orders WHERE user_id = 123;

-- ✅ 优化
SELECT order_id, order_no, total_amount, status, created_at
FROM orders
WHERE user_id = 123;
```

### 反模式 2：函数导致索引失效

```sql
-- ❌ 低效
SELECT * FROM orders
WHERE DATE(created_at) = '2024-01-01';

-- ✅ 优化
SELECT * FROM orders
WHERE created_at >= '2024-01-01'
    AND created_at < '2024-01-02';
```

### 反模式 3：大偏移分页

```sql
-- ❌ 低效
SELECT * FROM orders
ORDER BY created_at DESC
LIMIT 10 OFFSET 1000000;

-- ✅ 优化（游标分页）
SELECT * FROM orders
WHERE created_at < '2024-01-15 14:30:00' -- 上一页最后一条的时间
ORDER BY created_at DESC
LIMIT 10;
```

### 反模式 4：隐式类型转换

```sql
-- ❌ 低效（user_id 是 BIGINT）
SELECT * FROM orders WHERE user_id = '12345';

-- ✅ 优化
SELECT * FROM orders WHERE user_id = 12345;
```

### 反模式 5：NOT IN 子查询（含 NULL）

```sql
-- ❌ 危险（子查询含 NULL 时结果为空）
SELECT * FROM users
WHERE id NOT IN (SELECT user_id FROM banned_users);

-- ✅ 优化（使用 NOT EXISTS）
SELECT * FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM banned_users b WHERE b.user_id = u.id
);
```

### 反模式 6：UNION 去重（不需要时）

```sql
-- ❌ 低效（如果确定无重复）
SELECT user_id FROM orders_2023
UNION
SELECT user_id FROM orders_2024;

-- ✅ 优化
SELECT user_id FROM orders_2023
UNION ALL
SELECT user_id FROM orders_2024;
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

-- MaxCompute：无传统索引概念，靠分区裁剪 + MAPJOIN 优化，无需维护索引
```

---

## 阿里云 AnalyticDB for MySQL 方言差异

### 概述

AnalyticDB for MySQL（简称ADB MySQL）是阿里云自研的云原生实时数据仓库，高度兼容MySQL协议和语法，专为OLAP分析场景优化。

**核心特点**：
- ✅ 高度兼容MySQL协议
- ✅ 分布式列存架构
- ✅ 支持实时写入和秒级查询
- ⚠️ 不支持事务（ACID）
- ⚠️ DDL语法与MySQL有差异

### DDL语法差异

#### 1. 创建分布式表

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

#### 2. 分布键选择原则

| 原则 | 说明 | 示例 |
|------|------|------|
| 高基数 | 选择唯一值多的字段 | order_id, user_id |
| JOIN友好 | 选择常用于JOIN的字段 | user_id |
| 分布均匀 | 避免数据倾斜 | ❌ status（只有几个值） |

#### 3. 分区策略

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

#### 4. 聚簇索引（ADB特有）

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

#### 5. 二级索引

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

### DML语法差异

#### 1. INSERT语句

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

#### 2. UPDATE/DELETE

```sql
-- 语法兼容MySQL，但性能较低
UPDATE fct_orders SET status = 'completed' WHERE order_id = 1;
DELETE FROM fct_orders WHERE order_id = 1;

-- 性能建议：
-- 1. 尽量使用INSERT OVERWRITE替代大批量更新
-- 2. 小批量操作可以接受
-- 3. 大批量更新建议重建表
```

### 函数差异

#### 日期函数

| 功能 | MySQL | ADB MySQL | 兼容性 |
|------|-------|-----------|--------|
| 当前日期 | `CURDATE()` | `CURRENT_DATE` / `CURDATE()` | ✅ |
| 当前时间 | `NOW()` | `NOW()` / `CURRENT_TIMESTAMP` | ✅ |
| 日期格式化 | `DATE_FORMAT(d,f)` | `DATE_FORMAT(d,f)` | ✅ |
| 日期加减 | `DATE_ADD(d,i)` | `DATE_ADD(d,i)` | ✅ |
| 日期差 | `DATEDIFF(d1,d2)` | `DATEDIFF(d1,d2)` | ✅ |
| 时间戳转换 | `FROM_UNIXTIME(t)` | `FROM_UNIXTIME(t)` | ✅ |

#### 聚合函数

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

#### 窗口函数

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

### 数据类型差异

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

### 性能优化

#### 1. 分区裁剪

```sql
-- ✅ 推荐：查询包含分区条件
SELECT * FROM fct_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '202401'  -- 分区裁剪
  AND user_id = 1001;

-- ❌ 避免：不带分区条件，全分区扫描
SELECT * FROM fct_orders WHERE user_id = 1001;
```

#### 2. 聚簇索引优化

```sql
-- 场景：频繁按用户+时间查询
-- ⚠️ ADB不支持独立CREATE CLUSTERED INDEX，在CREATE TABLE中内联定义：
--   CLUSTERED KEY idx_cluster_user_time(user_id, order_time)
-- 或通过ALTER TABLE添加：
--   ALTER TABLE fct_orders ADD CLUSTERED KEY idx_cluster_user_time(user_id, order_time);

-- 效果：数据按索引顺序存储，查询性能提升
```

#### 3. 近似计算优化

```sql
-- 大数据量去重，使用近似函数
SELECT APPROX_COUNT_DISTINCT(user_id) AS uv
FROM fct_orders
WHERE order_time >= '2024-01-01';
-- 性能提升10倍以上，误差<1%
```

### 限制与约束

#### 不支持的功能

| 功能 | MySQL | ADB MySQL | 替代方案 |
|------|-------|-----------|---------|
| 事务 | ✅ ACID | ❌ 不支持 | 使用INSERT OVERWRITE |
| 外键 | ✅ 支持 | ✅ 支持（内核 3.1.10+） | ADB 外键仅用于 JOIN 消除优化，不做数据完整性校验，且不支持复合外键（多列）。详见 [官方文档](https://help.aliyun.com/zh/analyticdb/analyticdb-for-mysql/developer-reference/create-table) |
| 触发器 | ✅ 支持 | ❌ 不支持 | 使用ETL流程 |
| 存储过程 | ✅ 支持 | ❌ 不支持 | 使用外部脚本 |
| 自定义函数 | ✅ 支持 | ❌ 不支持 | 使用内置函数 |
| 临时表 | ✅ TEMPORARY | ❌ 不支持 | 创建普通表后删除 |

#### 性能特点

| 操作 | 性能 | 建议 |
|------|------|------|
| 批量INSERT | ⚡ 极快 | 每批5000-10000行 |
| 单行INSERT | 🐢 较慢 | 避免使用 |
| UPDATE/DELETE | 🐢 较慢 | 使用INSERT OVERWRITE |
| 分析查询 | ⚡ 极快 | 列存优势 |
| 单点查询 | 🐢 较慢 | 使用聚簇索引优化 |

### 最佳实践

#### 表设计

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

#### ETL流程

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

### 与其他数据库对比

> 本表仅供技术架构对比理解，**不代表本套件支持 MySQL/PostgreSQL/ClickHouse**。生产代码仅使用 AnalyticDB MySQL 和 MaxCompute。

| 特性 | MySQL | ADB MySQL | PostgreSQL | ClickHouse |
|------|-------|-----------|------------|------------|
| 架构 | 单机/主从 | 分布式 | 单机/主从 | 分布式 |
| 存储引擎 | InnoDB行存 | 列存 | Heap | MergeTree |
| 事务支持 | ✅ ACID | ❌ 不支持 | ✅ ACID | ❌ 有限 |
| 分布键 | - | DISTRIBUTED BY | - | ORDER BY |
| 分区表 | PARTITION BY RANGE | PARTITION BY VALUE | PARTITION BY RANGE | PARTITION BY |
| 聚簇索引 | 主键聚簇 | 可选CLUSTERED | 主键聚簇 | ORDER BY |
| 适用场景 | OLTP | OLAP | HTAP | OLAP |
| 兼容性 | 标准 | MySQL协议 | 标准 | SQL扩展 |

---

## 阿里云 MaxCompute 方言差异

### 概述

MaxCompute（原ODPS）是阿里云自主研发的大数据计算服务，专为海量数据处理设计。

**核心特点**：
- ✅ 海量数据处理能力
- ✅ 高性价比
- ✅ 分区表支持
- ⚠️ 不支持事务
- ⚠️ 有特有SQL语法

### DDL语法差异

#### 1. 创建分区表

```sql
-- MaxCompute 分区表创建
CREATE TABLE IF NOT EXISTS orders (
    order_id BIGINT COMMENT '订单ID',
    user_id BIGINT COMMENT '用户ID',
    order_time DATETIME COMMENT '订单时间',
    amount DECIMAL(18,2) COMMENT '金额',
    status STRING COMMENT '状态'
)
COMMENT '订单表'
PARTITIONED BY (
    pt STRING COMMENT '月分区YYYYMM',
    dt STRING COMMENT '日分区DD'
)
LIFECYCLE 365;  -- 数据生命周期365天

-- 添加分区
ALTER TABLE orders ADD PARTITION (pt='202401', dt='01');

-- 删除分区
ALTER TABLE orders DROP PARTITION (pt='202312', dt='01');
```

#### 2. 数据类型

| 类型 | 说明 | 示例 |
|------|------|------|
| `BIGINT` | 64位整数 | `1234567890` |
| `DOUBLE` | 双精度浮点 | `3.14159` |
| `STRING` | 字符串 | `'hello'` |
| `DATETIME` | 日期时间 | `2024-01-15 10:00:00` |
| `BOOLEAN` | 布尔值 | `TRUE/FALSE` |
| `DECIMAL` | 高精度小数 | `DECIMAL(18,2)` |
| `ARRAY` | 数组 | `ARRAY<STRING>` |
| `MAP` | 映射 | `MAP<STRING,STRING>` |

### DML语法差异

#### 1. 查询语法

```sql
-- 分区裁剪（必须）
SELECT * FROM orders
WHERE pt = '202401' AND dt >= '01' AND dt <= '31';

-- MAPJOIN优化（小表JOIN）
SELECT /*+ MAPJOIN(dim_user) */
    o.order_id,
    u.username
FROM orders o
JOIN dim_user u ON o.user_id = u.user_id;

-- 动态分区插入
INSERT OVERWRITE TABLE orders PARTITION(pt, dt)
SELECT 
    order_id,
    user_id,
    amount,
    DATE_FORMAT(order_time, '%Y%m') AS pt,
    DATE_FORMAT(order_time, '%d') AS dt
FROM source_orders;
```

#### 2. 函数差异

| 功能 | MySQL | MaxCompute |
|------|-------|------------|
| 当前日期 | `CURDATE()` | `GETDATE()` |
| 日期格式化 | `DATE_FORMAT(d,f)` | `DATE_FORMAT(d,f)` |
| 字符串拼接 | `CONCAT(s1,s2)` | `CONCAT(s1,s2)` |
| 条件判断 | `IF(cond,a,b)` | `IF(cond,a,b)` / `CASE WHEN` |
| 分组连接 | `GROUP_CONCAT()` | `WM_CONCAT()` |

### 性能优化

#### 1. 分区裁剪

```sql
-- ✅ 推荐：使用分区条件
SELECT * FROM orders
WHERE pt = '202401';

-- ❌ 避免：全表扫描
SELECT * FROM orders;
```

#### 2. MAPJOIN优化

```sql
-- 小表JOIN使用MAPJOIN
SELECT /*+ MAPJOIN(small_table) */ *
FROM large_table l
JOIN small_table s ON l.key = s.key;
```

#### 3. 并行执行

```sql
-- 设置并行度
SET odps.sql.parallel.factor=10;

-- 设置Reducer数量
SET odps.sql.reducer.instances=100;
```

### 最佳实践

1. **必须使用分区**：MaxCompute表必须有分区
2. **分区裁剪**：查询时必须包含分区条件
3. **生命周期管理**：设置合理的生命周期
4. **小文件合并**：避免产生大量小文件

---

## 历史参考：Hologres 方言对比

Hologres 是阿里云实时数据仓库，团队已不再使用，此处保留作为技术对比参考。

| 特性 | MaxCompute | AnalyticDB MySQL | Hologres（参考） |
|------|-----------|-----------------|-----------------|
| **架构** | 离线批处理 | 分布式数仓 | 实时数仓 |
| **存储类型** | 自动 | 列存 | 行存/列存 |
| **分区** | 分区字段定义 | PARTITION BY VALUE | 分区表 |
| **分布键** | 自动 | DISTRIBUTED BY HASH | distribution_key |
| **索引** | 无 | 聚簇索引 | 聚簇索引 |
| **事务支持** | ❌ | ❌ | ✅ |
| **实时性** | 批处理 | 准实时 | 实时 |
| **适用场景** | 海量离线 | OLAP分析 | 实时分析 |

### 选择建议

| 场景 | 推荐数据库 | 原因 |
|------|-----------|------|
| 海量离线处理（日志/埋点） | MaxCompute | 成本低、稳定性高 |
| OLAP 数仓（业务数据） | AnalyticDB MySQL | 兼容 MySQL、高性能 |

---

## Flink SQL 函数对照

Flink 实时计算（阿里云）常用于实时数据同步，其 SQL 语法与 ADB MySQL 存在差异：

### 常用函数差异

| 功能 | ADB MySQL | Flink SQL | 说明 |
|------|-----------|-----------|------|
| 当前时间 | `NOW()` | `CURRENT_TIMESTAMP` / `NOW()` | |
| 事件时间 | - | `WATERMARK FOR ts AS ts - INTERVAL '5' SECOND` | Flink 特有 |
| 字符串拼接 | `CONCAT(s1,s2)` | `s1 \|\| s2` / `CONCAT(s1,s2)` | |
| 日期格式化 | `DATE_FORMAT(d,f)` | `DATE_FORMAT(d,f)` | |
| JSON 提取 | `JSON_EXTRACT(j,p)` | `JSON_VALUE(j,p)` | |
| 窗口函数 | 标准 SQL 窗口 | `TUMBLE`/`HOP`/`SESSION` 窗口 | Flink 特有 |
| 去重 | `COUNT(DISTINCT col)` | `COUNT(DISTINCT col)` | |

### Flink 实时同步典型模式

```sql
-- Flink SQL: 从 Kafka 读取埋点日志，写入 ADB MySQL
CREATE TABLE kafka_source (
    event_time  TIMESTAMP(3),
    user_id     BIGINT,
    event_type  STRING,
    page_url    STRING,
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'user_behavior_log',
    'properties.bootstrap.servers' = 'kafka-broker:9092',
    'format' = 'json'
);

CREATE TABLE adb_sink (
    dt          STRING,
    user_id     BIGINT,
    event_type  STRING,
    pv          BIGINT,
    PRIMARY KEY (dt, user_id, event_type) NOT ENFORCED
) WITH (
    'connector' = 'adb-mysql',
    'url' = 'jdbc:mysql://adb-instance:3306/db',
    'table-name' = 'dwd_user_behavior_1d',
    'username' = 'user',
    'password' = 'password'
);

INSERT INTO adb_sink
SELECT
    DATE_FORMAT(event_time, '%Y%m%d') AS dt,
    user_id,
    event_type,
    COUNT(*) AS pv
FROM kafka_source
GROUP BY
    DATE_FORMAT(event_time, '%Y%m%d'),
    user_id,
    event_type;
```

---

## DataX 数据同步实践

DataX 是阿里巴巴开源的数据同步工具，部署在 ECS 上，用于 ADB MySQL 和 MaxCompute 之间的数据同步。

### Reader/Writer 配置模板

```json
{
  "job": {
    "content": [
      {
        "reader": {
          "name": "mysqlreader",
          "parameter": {
            "username": "user",
            "password": "password",
            "column": ["order_id", "user_id", "amount", "order_time"],
            "splitPk": "order_id",
            "connection": [
              {
                "table": ["orders"],
                "jdbcUrl": ["jdbc:mysql://source:3306/db"]
              }
            ]
          }
        },
        "writer": {
          "name": "adbpgwriter",
          "parameter": {
            "username": "user",
            "password": "password",
            "column": ["order_id", "user_id", "amount", "order_time"],
            "preSql": ["DELETE FROM fct_orders WHERE dt='${bizdate}'"],
            "postSql": [],
            "connection": [
              {
                "table": ["fct_orders"],
                "jdbcUrl": "jdbc:mysql://adb-instance:3306/db"
              }
            ]
          }
        }
      }
    ],
    "setting": {
      "speed": {
        "channel": 5,
        "byte": 10485760
      }
    }
  }
}
```

### 同步策略选择

| 策略 | DataX 配置方式 | 适用场景 |
|------|-------------|---------|
| **全量同步** | 直接 Reader→Writer | 数据量小、首次同步 |
| **增量同步** | `preSql` 清理 + `WHERE` 过滤 | 日常 ETL、T+1 更新 |
| **分区覆盖** | `INSERT OVERWRITE PARTITION` | ADB MySQL 按月/日分区覆盖 |

### DolphinScheduler 调度 DataX 任务

```bash
# DolphinScheduler 工作流节点：执行 DataX 任务
python /opt/datax/bin/datax.py /opt/datax/job/orders_sync.json
```

---

## 参考资料

- [阿里云 AnalyticDB for MySQL 文档](https://help.aliyun.com/product/190244.html)
- [阿里云 MaxCompute 文档](https://help.aliyun.com/product/27748.html)
- [阿里云 DataWorks 文档](https://help.aliyun.com/product/72772.html)
- [阿里云 Flink 实时计算文档](https://help.aliyun.com/product/43570.html)
- [DataX GitHub](https://github.com/alibaba/DataX)
- [Apache DolphinScheduler 文档](https://dolphinscheduler.apache.org/zh-cn/docs)
