# ADB MySQL DDL 创建示例

本文档提供阿里云AnalyticDB for MySQL的DDL创建示例，涵盖事实表、维度表、聚簇索引等场景。

---

## 示例1：电商订单事实表

### 业务场景

电商数据仓库的核心事实表，记录订单商品项级别数据，日增量10万订单，需要支持：
- 按用户维度分析消费行为
- 按时间维度分析销售趋势
- 按商品维度分析品类表现

### 完整DDL

```sql
-- ============================================
-- 表名：fct_order_items
-- 用途：订单商品项事实表（最细粒度）
-- 数据库：AnalyticDB for MySQL 3.0
-- 设计要点：
--   1. 分布键：order_id（高基数，JOIN友好）
--   2. 分区键：order_time（按月分区，便于裁剪）
--   3. 主键：order_item_id + order_time（必须含分区键）
--   4. 聚簇索引：优化用户维度查询
-- ============================================

CREATE TABLE fct_order_items (
    -- 主键字段
    order_item_id BIGINT NOT NULL COMMENT '订单项ID',
    order_time DATETIME NOT NULL COMMENT '订单时间（分区键）',

    -- 维度外键
    order_id BIGINT NOT NULL COMMENT '订单ID（分布键）',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    product_id BIGINT NOT NULL COMMENT '商品ID',
    category_id BIGINT COMMENT '分类ID',
    region_code VARCHAR(10) COMMENT '区域编码',

    -- 退化维度
    order_status VARCHAR(20) COMMENT '订单状态',
    payment_method VARCHAR(20) COMMENT '支付方式',

    -- 度量字段
    quantity INT COMMENT '购买数量',
    unit_price DECIMAL(10,2) COMMENT '商品单价',
    discount_amount DECIMAL(10,2) COMMENT '优惠金额',
    total_amount DECIMAL(18,2) COMMENT '实付金额',

    -- 审计字段
    etl_time DATETIME COMMENT 'ETL处理时间',

    -- 主键定义（必须包含分区键order_time）
    PRIMARY KEY (order_id, order_item_id, order_time),

    -- 聚簇索引（优化用户维度查询，ADB不支持独立CREATE CLUSTERED INDEX，必须内联定义）
    CLUSTERED KEY idx_cluster_user_time(user_id, order_time),

    -- 二级索引（ADB不支持独立CREATE INDEX，必须内联定义；每个普通索引只能含一列）
    INDEX idx_order_status(order_status),
    INDEX idx_region_code(region_code)
)
-- 分布键：选择高基数的order_id
DISTRIBUTED BY HASH(order_id)
-- 分区策略：按月分区
PARTITION BY VALUE(DATE_FORMAT(order_time, '%Y%m'))
-- 分区数量：24个分区，保留2年数据
PARTITIONS 24
COMMENT '订单商品项事实表';

-- ⚠️ ADB不支持独立CREATE INDEX / CREATE CLUSTERED INDEX语句
-- 所有索引必须在CREATE TABLE中内联定义，或通过ALTER TABLE ADD INDEX / ADD CLUSTERED KEY添加
```

### 设计说明

#### 分布键选择：order_id

| 选择原因 | 说明 |
|---------|------|
| 高基数 | 每日10万+订单，数据分布均匀 |
| JOIN友好 | 订单表常与用户、商品表JOIN |
| 无倾斜风险 | 订单ID均匀分布，不存在热点 |

#### 分区策略：按月分区

| 设计考虑 | 说明 |
|---------|------|
| 分区裁剪 | 查询时按月过滤，只扫描目标分区 |
| 数据生命周期 | 24个分区，保留2年，便于清理 |
| 分区键要求 | 主键必须包含order_time |

#### 聚簇索引：(user_id, order_time)

| 优化场景 | SQL示例 |
|---------|---------|
| 用户消费分析 | `WHERE user_id = ? AND order_time >= ?` |
| 用户订单历史 | `WHERE user_id = ? ORDER BY order_time DESC` |
| 索引命中效果 | 数据按索引顺序存储，减少IO |

---

## 示例2：用户维度表

### 业务场景

用户维度表，存储用户基础信息和属性，需要支持SCD Type 2（保留历史变更）。

### 完整DDL

```sql
-- ============================================
-- 表名：dim_users
-- 用途：用户维度表（SCD Type 2）
-- 数据库：AnalyticDB for MySQL
-- 设计要点：
--   1. 维度表通常不分区
--   2. 分布键：user_id
--   3. 支持历史版本追踪
-- ============================================

CREATE TABLE dim_users (
    -- 代理键
    user_sk BIGINT NOT NULL COMMENT '用户代理键',

    -- 自然键
    user_id BIGINT NOT NULL COMMENT '用户ID（自然键）',

    -- 用户属性
    username VARCHAR(100) COMMENT '用户名',
    email VARCHAR(100) COMMENT '邮箱',
    phone VARCHAR(20) COMMENT '手机号',
    city VARCHAR(50) COMMENT '城市',
    user_level VARCHAR(20) COMMENT '用户等级',

    -- SCD Type 2 字段
    effective_start_date DATETIME COMMENT '生效开始时间',
    effective_end_date DATETIME COMMENT '生效结束时间',
    is_current BOOLEAN COMMENT '是否当前版本',

    -- 审计字段
    register_time DATETIME COMMENT '注册时间',
    last_update_time DATETIME COMMENT '最后更新时间',
    etl_time DATETIME COMMENT 'ETL处理时间',

    PRIMARY KEY (user_sk),

    -- 内联索引（ADB不支持独立CREATE INDEX，必须内联定义）
    INDEX idx_user_id(user_id),       -- 按自然键查询
    INDEX idx_is_current(is_current)  -- 查询当前版本
)
DISTRIBUTED BY HASH(user_id)
COMMENT '用户维度表（SCD Type 2）';
```

### SCD Type 2查询示例

```sql
-- 查询用户当前信息
SELECT user_id, username, city, user_level
FROM dim_users
WHERE user_id = 1001
  AND is_current = TRUE;

-- 查询用户历史变更
SELECT
    user_id,
    user_level,
    effective_start_date,
    effective_end_date,
    CASE WHEN is_current THEN '当前' ELSE '历史' END AS version_type
FROM dim_users
WHERE user_id = 1001
ORDER BY effective_start_date;
```

---

## 示例3：日志事实表（按日分区）

### 业务场景

用户行为日志表，日增量1000万条，需要按日分区便于快速清理历史数据。

### 完整DDL

```sql
-- ============================================
-- 表名：fct_user_logs
-- 用途：用户行为日志事实表
-- 数据库：AnalyticDB for MySQL
-- 设计要点：
--   1. 日增量1000万，按日分区
--   2. 保留90天数据
--   3. 聚簇索引优化用户维度查询
-- ============================================

CREATE TABLE fct_user_logs (
    -- 主键
    log_id BIGINT NOT NULL COMMENT '日志ID',
    log_time DATETIME NOT NULL COMMENT '日志时间',

    -- 维度
    user_id BIGINT COMMENT '用户ID',
    session_id VARCHAR(50) COMMENT '会话ID',
    device_id VARCHAR(50) COMMENT '设备ID',
    platform VARCHAR(20) COMMENT '平台（iOS/Android/Web）',

    -- 行为属性
    event_type VARCHAR(50) COMMENT '事件类型',
    event_name VARCHAR(100) COMMENT '事件名称',
    page_url VARCHAR(500) COMMENT '页面URL',

    -- 事件参数（JSON）
    event_params JSON COMMENT '事件参数',

    PRIMARY KEY (log_id, log_time),

    -- 聚簇索引（优化用户查询，ADB不支持独立CREATE CLUSTERED INDEX，必须内联定义）
    CLUSTERED KEY idx_cluster_user_log_time(user_id, log_time),

    -- 二级索引（优化事件类型筛选，ADB不支持独立CREATE INDEX，必须内联定义）
    INDEX idx_event_type(event_type)
)
DISTRIBUTED BY HASH(log_id)
PARTITION BY VALUE(DATE_FORMAT(log_time, '%Y%m%d'))  -- 按日分区
PARTITIONS 90  -- 保留90天
COMMENT '用户行为日志表';
```

### 分区清理示例

```sql
-- 清理90天前的数据（直接删除分区）
-- ADB 语法：DROP PARTITION (分区键列 = 分区值)
ALTER TABLE fct_user_logs DROP PARTITION (log_time = '20231201');
```

---

## 示例4：大宽表设计

### 业务场景

销售分析宽表，预JOIN用户和商品维度，避免查询时多表JOIN。

### 完整DDL

```sql
-- ============================================
-- 表名：ads_sales_wide
-- 用途：销售分析宽表（预JOIN设计）
-- 数据库：AnalyticDB for MySQL
-- 设计要点：
--   1. 冗余用户和商品属性，减少JOIN
--   2. 聚簇索引优化分析查询
-- ============================================

CREATE TABLE ads_sales_wide (
    -- 主键
    order_id BIGINT NOT NULL,
    order_time DATETIME NOT NULL,

    -- 用户属性（冗余）
    user_id BIGINT NOT NULL COMMENT '用户ID',
    user_name VARCHAR(100) COMMENT '用户名',
    user_level VARCHAR(20) COMMENT '用户等级',
    user_city VARCHAR(50) COMMENT '用户城市',
    user_gender VARCHAR(10) COMMENT '用户性别',

    -- 商品属性（冗余）
    product_id BIGINT NOT NULL COMMENT '商品ID',
    product_name VARCHAR(200) COMMENT '商品名',
    category_name VARCHAR(50) COMMENT '分类名',
    brand_name VARCHAR(50) COMMENT '品牌名',

    -- 订单属性
    quantity INT COMMENT '数量',
    unit_price DECIMAL(10,2) COMMENT '单价',
    total_amount DECIMAL(18,2) COMMENT '总金额',
    order_status VARCHAR(20) COMMENT '状态',

    PRIMARY KEY (order_id, order_time),

    -- 聚簇索引（优化多维分析，ADB不支持独立CREATE CLUSTERED INDEX，必须内联定义；CLUSTERED KEY支持多列）
    CLUSTERED KEY idx_cluster_analysis(user_id, category_name, order_time)
)
DISTRIBUTED BY HASH(order_id)
PARTITION BY VALUE(DATE_FORMAT(order_time, '%Y%m'))
PARTITIONS 12
COMMENT '销售分析宽表';
```

### 大宽表查询优势

```sql
-- 无需JOIN，直接查询
SELECT
    category_name,
    user_city,
    SUM(total_amount) AS sales_amount,
    COUNT(DISTINCT user_id) AS buyer_count
FROM ads_sales_wide
WHERE DATE_FORMAT(order_time, '%Y%m') = '202401'
GROUP BY category_name, user_city
ORDER BY sales_amount DESC;

-- 对比：需要JOIN多表的查询（性能差）
SELECT
    c.category_name,
    u.city,
    SUM(o.total_amount)
FROM fct_orders o
JOIN dim_users u ON o.user_id = u.user_id
JOIN dim_products p ON o.product_id = p.product_id
JOIN dim_categories c ON p.category_id = c.category_id
WHERE ...
GROUP BY ...
```

---

## 示例5：全文检索表

### 业务场景

商品评论全文检索，支持关键词搜索。

### 完整DDL

```sql
-- ============================================
-- 表名：fct_product_reviews
-- 用途：商品评论表（全文检索）
-- 数据库：AnalyticDB for MySQL
-- ============================================

CREATE TABLE fct_product_reviews (
    review_id BIGINT NOT NULL,
    review_time DATETIME NOT NULL,
    product_id BIGINT NOT NULL,
    user_id BIGINT,
    title VARCHAR(200) COMMENT '评论标题',
    content TEXT COMMENT '评论内容',
    rating INT COMMENT '评分（1-5）',

    -- 全文索引（ADB 仅支持单列 FULLTEXT INDEX；多列全文检索需用 OR 组合单列 MATCH）
    FULLTEXT INDEX idx_fulltext_title(title),
    FULLTEXT INDEX idx_fulltext_content(content),

    PRIMARY KEY (review_id, review_time)
)
DISTRIBUTED BY HASH(review_id)
PARTITION BY VALUE(DATE_FORMAT(review_time, '%Y%m'))
PARTITIONS 12
COMMENT '商品评论表';
```

### 全文检索查询

```sql
-- 自然语言模式搜索
SELECT
    review_id,
    product_id,
    title,
    content,
    rating
FROM fct_product_reviews
WHERE MATCH(title) AGAINST('质量好 性价比高' IN NATURAL LANGUAGE MODE)
   OR MATCH(content) AGAINST('质量好 性价比高' IN NATURAL LANGUAGE MODE)
ORDER BY review_time DESC
LIMIT 20;

-- BOOLEAN模式（精确匹配，单列 MATCH 用 OR 组合）
SELECT * FROM fct_product_reviews
WHERE MATCH(title) AGAINST('+好评 +物流快' IN BOOLEAN MODE)
   OR MATCH(content) AGAINST('+好评 +物流快' IN BOOLEAN MODE);

-- 短语匹配（单列）
SELECT * FROM fct_product_reviews
WHERE MATCH(title) AGAINST('"非常满意"' IN BOOLEAN MODE)
   OR MATCH(content) AGAINST('"非常满意"' IN BOOLEAN MODE);
```

---

## 示例6：JSON字段表

### 业务场景

事件参数存储，使用JSON字段存储动态属性。

### 完整DDL

```sql
-- ============================================
-- 表名：fct_events
-- 用途：事件表（JSON字段存储）
-- 数据库：AnalyticDB for MySQL
-- ============================================

CREATE TABLE fct_events (
    event_id BIGINT NOT NULL,
    event_time DATETIME NOT NULL,
    event_type VARCHAR(50),
    user_id BIGINT,

    -- JSON字段存储动态属性
    event_data JSON COMMENT '事件数据（JSON格式）',

    PRIMARY KEY (event_id, event_time)
)
DISTRIBUTED BY HASH(event_id)
PARTITION BY VALUE(DATE_FORMAT(event_time, '%Y%m'))
PARTITIONS 12;
```

### JSON查询示例

```sql
-- 提取JSON字段
SELECT
    event_id,
    event_type,
    JSON_UNQUOTE(JSON_EXTRACT(event_data, '$.page')) AS page,
    JSON_UNQUOTE(JSON_EXTRACT(event_data, '$.action')) AS action,
    JSON_EXTRACT(event_data, '$.duration') AS duration
FROM fct_events
WHERE event_type = 'click'
  AND DATE_FORMAT(event_time, '%Y%m') = '202401';

-- JSON条件过滤
SELECT * FROM fct_events
WHERE JSON_UNQUOTE(JSON_EXTRACT(event_data, '$.page')) = 'homepage';

-- JSON数组查询
SELECT * FROM fct_events
WHERE JSON_CONTAINS(event_data, '"vip"', '$.user_tags');
```

---

## 总结：ADB MySQL DDL最佳实践

| 设计要点 | 最佳实践 | 避免做法 |
|---------|---------|---------|
| 分布键 | 高基数字段（ID类） | 低基数字段（status等） |
| 分区键 | 时间字段，按月/日分区 | 不使用分区 |
| 主键 | 必须包含分区键 | 忽略此约束 |
| 聚簇索引 | 高频查询字段组合 | 随意创建 |
| 大宽表 | 冗余常用维度属性 | 过度范式化 |
| 数据类型 | VARCHAR/DECIMAL/JSON | LONGTEXT/LONGBLOB |

---

## 执行计划分析

使用 `EXPLAIN` 命令可以查看 ADB MySQL 如何执行查询，帮助验证分区裁剪、索引使用等优化是否生效：

```sql
-- 查看事实表查询的执行计划
EXPLAIN SELECT
    DATE_FORMAT(order_time, '%Y-%m') AS month,
    COUNT(DISTINCT order_id) AS order_count,
    SUM(total_amount) AS gmv
FROM fct_order_items
WHERE DATE_FORMAT(order_time, '%Y%m') = '202401'
GROUP BY DATE_FORMAT(order_time, '%Y-%m');
```

**关键观察点**：
- **分区裁剪**：执行计划中应显示只扫描 `202401` 分区，而非全部分区
- **聚簇索引使用**：如果查询包含聚簇索引字段（如 `user_id`），应显示索引扫描
- **分布键对齐**：JOIN 操作应显示分布键对齐，避免数据重分布

**优化建议**：
- 如果执行计划显示全分区扫描，检查 WHERE 条件是否包含分区字段
- 如果 JOIN 操作显示数据重分布，考虑调整分布键或使用 MAPJOIN
- 对于复杂查询，使用 `EXPLAIN ANALYZE` 查看实际执行时间