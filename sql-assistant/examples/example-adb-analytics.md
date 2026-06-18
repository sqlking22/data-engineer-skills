# ADB MySQL 分析查询示例

本文档提供阿里云AnalyticDB for MySQL的分析查询示例，涵盖用户行为分析、销售分析、留存分析等常见场景。

---

## 示例1：用户留存分析

### 业务需求

分析新用户在注册后7日内的留存情况，计算次日留存、3日留存、7日留存率。

### SQL实现

```sql
-- ============================================
-- 分析目的：新用户7日留存率分析
-- 目标数据库：AnalyticDB for MySQL
-- 优化策略：分区裁剪、近似去重
-- ============================================

WITH
-- Step 1: 获取新用户（按月分区裁剪）
new_users AS (
    SELECT
        user_id,
        DATE(register_time) AS register_date
    FROM dim_users
    WHERE DATE_FORMAT(register_time, '%Y%m') BETWEEN '202401' AND '202403'
),

-- Step 2: 获取用户活跃记录
user_activities AS (
    SELECT
        user_id,
        DATE(log_time) AS activity_date
    FROM fct_user_logs
    WHERE DATE_FORMAT(log_time, '%Y%m') BETWEEN '202401' AND '202403'
    GROUP BY user_id, DATE(log_time)
),

-- Step 3: 计算留存
retention_calc AS (
    SELECT
        nu.register_date,
        COUNT(DISTINCT nu.user_id) AS new_user_count,

        -- 次日留存
        COUNT(DISTINCT CASE
            WHEN DATEDIFF(ua.activity_date, nu.register_date) = 1
            THEN nu.user_id
        END) AS retention_day1,

        -- 3日留存
        COUNT(DISTINCT CASE
            WHEN DATEDIFF(ua.activity_date, nu.register_date) = 3
            THEN nu.user_id
        END) AS retention_day3,

        -- 7日留存
        COUNT(DISTINCT CASE
            WHEN DATEDIFF(ua.activity_date, nu.register_date) = 7
            THEN nu.user_id
        END) AS retention_day7

    FROM new_users nu
    LEFT JOIN user_activities ua
        ON nu.user_id = ua.user_id
        AND DATEDIFF(ua.activity_date, nu.register_date) BETWEEN 1 AND 7
    GROUP BY nu.register_date
)

-- 最终输出
SELECT
    register_date,
    new_user_count,
    retention_day1,
    retention_day3,
    retention_day7,
    CONCAT(ROUND(retention_day1 * 100.0 / new_user_count, 2), '%') AS retention_rate_day1,
    CONCAT(ROUND(retention_day3 * 100.0 / new_user_count, 2), '%') AS retention_rate_day3,
    CONCAT(ROUND(retention_day7 * 100.0 / new_user_count, 2), '%') AS retention_rate_day7
FROM retention_calc
ORDER BY register_date;

-- 性能提示：
-- 1. ✅ 已使用分区裁剪（DATE_FORMAT）
-- 2. ✅ 近似去重选项：可使用 APPROX_COUNT_DISTINCT(user_id) 提升性能
-- 3. 建议在 register_time 和 log_time 上创建聚簇索引
```

---

## 示例2：RFM用户分层分析

### 业务需求

基于RFM模型对用户进行分层，识别高价值用户、流失用户等。

### SQL实现

```sql
-- ============================================
-- 分析目的：RFM用户分层分析
-- R (Recency): 最近一次购买时间
-- F (Frequency): 购买频率
-- M (Monetary): 购买金额
-- ============================================

WITH
-- Step 1: 计算每个用户的RFM值
rfm_base AS (
    SELECT
        user_id,
        -- R: 最近一次购买距今天数
        DATEDIFF(CURRENT_DATE, MAX(DATE(order_time))) AS recency_days,
        -- F: 购买次数
        COUNT(DISTINCT order_id) AS frequency,
        -- M: 购买总金额
        SUM(amount) AS monetary
    FROM fct_orders
    WHERE DATE_FORMAT(order_time, '%Y%m') >= '202301'  -- 分区裁剪
      AND order_status = 'completed'
    GROUP BY user_id
),

-- Step 2: 计算RFM分数（1-5分）
rfm_scores AS (
    SELECT
        user_id,
        recency_days,
        frequency,
        monetary,
        -- R分数（越小越好，所以倒序）
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        -- F分数（越大越好）
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        -- M分数（越大越好）
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_base
),

-- Step 3: 用户分层
rfm_segments AS (
    SELECT
        user_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        r_score + f_score + m_score AS rfm_total,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN '重要价值用户'
            WHEN r_score >= 4 AND f_score < 4 AND m_score >= 4 THEN '重要发展用户'
            WHEN r_score < 4 AND f_score >= 4 AND m_score >= 4 THEN '重要保持用户'
            WHEN r_score < 4 AND f_score < 4 AND m_score >= 4 THEN '重要挽留用户'
            WHEN r_score >= 4 AND f_score >= 4 AND m_score < 4 THEN '一般价值用户'
            WHEN r_score >= 4 AND f_score < 4 AND m_score < 4 THEN '一般发展用户'
            WHEN r_score < 4 AND f_score >= 4 AND m_score < 4 THEN '一般保持用户'
            ELSE '低价值用户'
        END AS user_segment
    FROM rfm_scores
)

-- 最终输出：各层级用户统计
SELECT
    user_segment,
    COUNT(*) AS user_count,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency), 1) AS avg_frequency,
    ROUND(AVG(monetary), 2) AS avg_monetary,
    ROUND(AVG(monetary) * COUNT(*), 2) AS total_monetary
FROM rfm_segments
GROUP BY user_segment
ORDER BY total_monetary DESC;
```

---

## 示例3：商品销售排行榜

### 业务需求

生成商品销售排行榜，支持多维度排序和分页。

### SQL实现

```sql
-- ============================================
-- 分析目的：商品销售排行榜
-- 维度：品类、品牌、时间
-- 支持分页
-- ============================================

WITH
-- 基础销售统计
product_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category_name,
        p.brand_name,
        SUM(o.quantity) AS total_quantity,
        SUM(o.total_amount) AS total_amount,
        COUNT(DISTINCT o.order_id) AS order_count,
        APPROX_COUNT_DISTINCT(o.user_id) AS buyer_count  -- 近似UV
    FROM fct_order_items o
    JOIN dim_products p ON o.product_id = p.product_id
    WHERE DATE_FORMAT(o.order_time, '%Y%m') = '202401'  -- 分区裁剪
      AND o.order_status = 'completed'
    GROUP BY p.product_id, p.product_name, p.category_name, p.brand_name
)

-- 排行榜输出（支持分页）
SELECT
    ROW_NUMBER() OVER (ORDER BY total_amount DESC) AS rank,
    product_id,
    product_name,
    category_name,
    brand_name,
    total_quantity,
    total_amount,
    order_count,
    buyer_count,
    ROUND(total_amount / order_count, 2) AS avg_order_amount
FROM product_sales
ORDER BY total_amount DESC
LIMIT 20 OFFSET 0;  -- 分页：每页20条，第1页

-- 品类维度排行榜
SELECT
    ROW_NUMBER() OVER (ORDER BY total_amount DESC) AS rank,
    category_name,
    SUM(total_quantity) AS total_quantity,
    SUM(total_amount) AS total_amount,
    COUNT(DISTINCT product_id) AS product_count,
    APPROX_COUNT_DISTINCT(product_id) AS sku_count
FROM product_sales
GROUP BY category_name
ORDER BY total_amount DESC;

-- 品牌维度排行榜
SELECT
    ROW_NUMBER() OVER (ORDER BY total_amount DESC) AS rank,
    brand_name,
    category_name,
    SUM(total_amount) AS total_amount
FROM product_sales
GROUP BY brand_name, category_name
ORDER BY total_amount DESC
LIMIT 50;
```

---

## 示例4：用户行为漏斗分析

### 业务需求

分析用户从浏览商品到下单的转化漏斗。

### SQL实现

```sql
-- ============================================
-- 分析目的：用户行为漏斗分析
-- 漏斗环节：浏览 → 加购 → 下单 → 支付
-- ============================================

WITH
-- 定义漏斗环节
funnel_steps AS (
    SELECT
        user_id,
        -- 是否浏览
        MAX(CASE WHEN event_name = 'view_product' THEN 1 ELSE 0 END) AS step1_view,
        -- 是否加购
        MAX(CASE WHEN event_name = 'add_cart' THEN 1 ELSE 0 END) AS step2_cart,
        -- 是否下单
        MAX(CASE WHEN event_name = 'create_order' THEN 1 ELSE 0 END) AS step3_order,
        -- 是否支付
        MAX(CASE WHEN event_name = 'pay_order' THEN 1 ELSE 0 END) AS step4_pay
    FROM fct_user_logs
    WHERE DATE_FORMAT(log_time, '%Y%m') = '202401'  -- 分区裁剪
    GROUP BY user_id
),

-- 计算漏斗转化
funnel_calc AS (
    SELECT
        COUNT(*) AS total_users,
        SUM(step1_view) AS view_users,
        SUM(step2_cart) AS cart_users,
        SUM(step3_order) AS order_users,
        SUM(step4_pay) AS pay_users,
        -- 计算转化率
        ROUND(SUM(step1_view) * 100.0 / COUNT(*), 2) AS view_rate,
        ROUND(SUM(step2_cart) * 100.0 / NULLIF(SUM(step1_view), 0), 2) AS cart_rate,
        ROUND(SUM(step3_order) * 100.0 / NULLIF(SUM(step2_cart), 0), 2) AS order_rate,
        ROUND(SUM(step4_pay) * 100.0 / NULLIF(SUM(step3_order), 0), 2) AS pay_rate
    FROM funnel_steps
)

-- 输出漏斗结果
SELECT
    '步骤1：浏览商品' AS funnel_step,
    view_users AS user_count,
    100.00 AS conversion_rate
FROM funnel_calc
UNION ALL
SELECT
    '步骤2：加入购物车' AS funnel_step,
    cart_users AS user_count,
    cart_rate AS conversion_rate
FROM funnel_calc
UNION ALL
SELECT
    '步骤3：创建订单' AS funnel_step,
    order_users AS user_count,
    order_rate AS conversion_rate
FROM funnel_calc
UNION ALL
SELECT
    '步骤4：完成支付' AS funnel_step,
    pay_users AS user_count,
    pay_rate AS conversion_rate
FROM funnel_calc;

-- 整体转化率
SELECT
    ROUND(SUM(step4_pay) * 100.0 / NULLIF(SUM(step1_view), 0), 2) AS overall_conversion_rate
FROM funnel_steps;
```

---

## 示例5：销售同环比分析

### 业务需求

分析销售额的同比增长和环比增长趋势。

### SQL实现

```sql
-- ============================================
-- 分析目的：销售同环比分析
-- 同比：与去年同期比较
-- 环比：与上月同期比较
-- ============================================

WITH
-- 按月汇总销售数据
monthly_sales AS (
    SELECT
        DATE_FORMAT(order_time, '%Y%m') AS month_id,
        SUM(amount) AS total_amount,
        COUNT(DISTINCT order_id) AS order_count,
        APPROX_COUNT_DISTINCT(user_id) AS buyer_count
    FROM fct_orders
    WHERE DATE_FORMAT(order_time, '%Y%m') BETWEEN '202301' AND '202403'
      AND order_status = 'completed'
    GROUP BY DATE_FORMAT(order_time, '%Y%m')
)

-- 同环比计算
SELECT
    curr.month_id,
    curr.total_amount,
    curr.order_count,
    curr.buyer_count,

    -- 同比（去年同期）
    ly.total_amount AS amount_ly,
    ly.order_count AS order_count_ly,
    ROUND((curr.total_amount - ly.total_amount) * 100.0 / NULLIF(ly.total_amount, 0), 2) AS yoy_amount_rate,
    ROUND((curr.order_count - ly.order_count) * 100.0 / NULLIF(ly.order_count, 0), 2) AS yoy_order_rate,

    -- 环比（上月）
    lm.total_amount AS amount_lm,
    lm.order_count AS order_count_lm,
    ROUND((curr.total_amount - lm.total_amount) * 100.0 / NULLIF(lm.total_amount, 0), 2) AS mom_amount_rate,
    ROUND((curr.order_count - lm.order_count) * 100.0 / NULLIF(lm.order_count, 0), 2) AS mom_order_rate

FROM monthly_sales curr
-- 关联去年同期
LEFT JOIN monthly_sales ly
    ON ly.month_id = DATE_FORMAT(DATE_SUB(STR_TO_DATE(CONCAT(curr.month_id, '01'), '%Y%m%d'), INTERVAL 1 YEAR), '%Y%m')
-- 关联上月
LEFT JOIN monthly_sales lm
    ON lm.month_id = DATE_FORMAT(DATE_SUB(STR_TO_DATE(CONCAT(curr.month_id, '01'), '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m')
ORDER BY curr.month_id;

-- 多维度同环比（按区域）
SELECT
    DATE_FORMAT(order_time, '%Y%m') AS month_id,
    region_code,
    SUM(amount) AS total_amount,
    LAG(SUM(amount), 12) OVER (PARTITION BY region_code ORDER BY DATE_FORMAT(order_time, '%Y%m')) AS amount_ly,
    LAG(SUM(amount), 1) OVER (PARTITION BY region_code ORDER BY DATE_FORMAT(order_time, '%Y%m')) AS amount_lm
FROM fct_orders
WHERE DATE_FORMAT(order_time, '%Y%m') BETWEEN '202301' AND '202403'
  AND order_status = 'completed'
GROUP BY DATE_FORMAT(order_time, '%Y%m'), region_code
ORDER BY region_code, month_id;
```

---

## 示例6：用户行为路径分析

### 业务需求

分析用户在APP内的行为路径，了解用户操作序列。

### SQL实现

```sql
-- ============================================
-- 分析目的：用户行为路径分析
-- 分析用户从首页到下单的典型路径
-- ============================================

WITH
-- 按用户会话分组，记录行为序列
user_sessions AS (
    SELECT
        user_id,
        session_id,
        event_name,
        log_time,
        -- 按时间排序的行为序号
        ROW_NUMBER() OVER (PARTITION BY user_id, session_id ORDER BY log_time) AS event_seq,
        -- 下一个事件
        LEAD(event_name, 1) OVER (PARTITION BY user_id, session_id ORDER BY log_time) AS next_event
    FROM fct_user_logs
    WHERE DATE_FORMAT(log_time, '%Y%m%d') = '20240115'  -- 按日分区裁剪
),

-- 统计路径转换
path_transitions AS (
    SELECT
        event_name AS current_event,
        next_event,
        COUNT(*) AS transition_count
    FROM user_sessions
    WHERE next_event IS NOT NULL
    GROUP BY event_name, next_event
)

-- 输出最常见的路径转换
SELECT
    current_event,
    next_event,
    transition_count,
    ROUND(transition_count * 100.0 / SUM(transition_count) OVER (PARTITION BY current_event), 2) AS transition_rate
FROM path_transitions
ORDER BY transition_count DESC
LIMIT 20;

-- 分析完整路径（首页到下单）
WITH complete_paths AS (
    SELECT
        user_id,
        session_id,
        GROUP_CONCAT(event_name ORDER BY event_seq SEPARATOR ' → ') AS path
    FROM user_sessions
    WHERE event_seq <= 10  -- 最多看10步
    GROUP BY user_id, session_id
    HAVING path LIKE '%view_home%pay_order%'  -- 从首页到支付
)

SELECT
    path,
    COUNT(*) AS path_count
FROM complete_paths
GROUP BY path
ORDER BY path_count DESC
LIMIT 20;
```

---

## 示例7：实时销售监控大屏

### 业务需求

实时监控当日销售数据，支持大屏展示。

### SQL实现

```sql
-- ============================================
-- 分析目的：实时销售监控
-- 数据源：当日订单数据
-- 刷新频率：分钟级
-- ============================================

-- 核心指标卡片
SELECT
    -- 总销售额
    (SELECT SUM(amount) FROM fct_orders
     WHERE DATE(order_time) = CURRENT_DATE
       AND order_status = 'completed') AS total_sales,

    -- 订单数
    (SELECT COUNT(*) FROM fct_orders
     WHERE DATE(order_time) = CURRENT_DATE) AS total_orders,

    -- 实时UV
    (SELECT APPROX_COUNT_DISTINCT(user_id) FROM fct_orders
     WHERE DATE(order_time) = CURRENT_DATE) AS online_users,

    -- 客单价
    (SELECT ROUND(AVG(amount), 2) FROM fct_orders
     WHERE DATE(order_time) = CURRENT_DATE
       AND order_status = 'completed') AS avg_order_amount;

-- 按小时销售趋势
SELECT
    DATE_FORMAT(order_time, '%H:00') AS hour_slot,
    COUNT(*) AS order_count,
    SUM(amount) AS hour_sales
FROM fct_orders
WHERE DATE(order_time) = CURRENT_DATE
GROUP BY DATE_FORMAT(order_time, '%H:00')
ORDER BY hour_slot;

-- 实时区域销售排行
SELECT
    region_code,
    SUM(amount) AS total_amount,
    COUNT(*) AS order_count
FROM fct_orders
WHERE DATE(order_time) = CURRENT_DATE
GROUP BY region_code
ORDER BY total_amount DESC
LIMIT 10;

-- 实时商品销售排行
SELECT
    product_id,
    product_name,
    SUM(quantity) AS total_quantity,
    SUM(total_amount) AS total_amount
FROM fct_order_items
WHERE DATE(order_time) = CURRENT_DATE
GROUP BY product_id, product_name
ORDER BY total_amount DESC
LIMIT 10;

-- 同比对比（今日vs昨日同时段）
SELECT
    '今日' AS day_type,
    SUM(amount) AS total_sales,
    COUNT(*) AS order_count
FROM fct_orders
WHERE DATE(order_time) = CURRENT_DATE
  AND DATE_FORMAT(order_time, '%H') <= DATE_FORMAT(CURRENT_TIMESTAMP, '%H')

UNION ALL

SELECT
    '昨日' AS day_type,
    SUM(amount) AS total_sales,
    COUNT(*) AS order_count
FROM fct_orders
WHERE DATE(order_time) = DATE_SUB(CURRENT_DATE, INTERVAL 1 DAY)
  AND DATE_FORMAT(order_time, '%H') <= DATE_FORMAT(CURRENT_TIMESTAMP, '%H');
```

---

## 示例8：用户画像标签计算

### 业务需求

基于用户行为数据，计算用户画像标签。

### SQL实现

```sql
-- ============================================
-- 分析目的：用户画像标签计算
-- 标签维度：消费能力、活跃度、偏好类目
-- ============================================

WITH
-- 消费能力标签
consumption_tags AS (
    SELECT
        user_id,
        SUM(amount) AS total_amount,
        COUNT(DISTINCT order_id) AS order_count,
        CASE
            WHEN SUM(amount) >= 10000 THEN '高消费'
            WHEN SUM(amount) >= 5000 THEN '中高消费'
            WHEN SUM(amount) >= 1000 THEN '中等消费'
            ELSE '低消费'
        END AS consumption_level
    FROM fct_orders
    WHERE DATE_FORMAT(order_time, '%Y%m') >= DATE_FORMAT(DATE_SUB(CURRENT_DATE, INTERVAL 6 MONTH), '%Y%m')
      AND order_status = 'completed'
    GROUP BY user_id
),

-- 活跃度标签
activity_tags AS (
    SELECT
        user_id,
        COUNT(DISTINCT DATE(log_time)) AS active_days,
        CASE
            WHEN COUNT(DISTINCT DATE(log_time)) >= 20 THEN '高活跃'
            WHEN COUNT(DISTINCT DATE(log_time)) >= 10 THEN '中活跃'
            WHEN COUNT(DISTINCT DATE(log_time)) >= 5 THEN '低活跃'
            ELSE '沉默'
        END AS activity_level
    FROM fct_user_logs
    WHERE DATE_FORMAT(log_time, '%Y%m') >= DATE_FORMAT(DATE_SUB(CURRENT_DATE, INTERVAL 1 MONTH), '%Y%m')
    GROUP BY user_id
),

-- 偏好类目标签
category_tags AS (
    SELECT
        user_id,
        category_name,
        SUM(amount) AS category_amount,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY SUM(amount) DESC) AS category_rank
    FROM fct_order_items
    WHERE DATE_FORMAT(order_time, '%Y%m') >= DATE_FORMAT(DATE_SUB(CURRENT_DATE, INTERVAL 6 MONTH), '%Y%m')
      AND order_status = 'completed'
    GROUP BY user_id, category_name
)

-- 整合用户画像
SELECT
    u.user_id,
    u.username,
    u.city,

    -- 消费标签
    COALESCE(c.total_amount, 0) AS total_consumption,
    COALESCE(c.consumption_level, '无消费') AS consumption_level,

    -- 活跃标签
    COALESCE(a.active_days, 0) AS active_days_30d,
    COALESCE(a.activity_level, '沉默') AS activity_level,

    -- 偏好类目
    ct.category_name AS preferred_category,

    -- 综合标签
    CONCAT(
        COALESCE(c.consumption_level, '无消费'), '-',
        COALESCE(a.activity_level, '沉默'),
        CASE WHEN ct.category_name IS NOT NULL THEN CONCAT('-', ct.category_name) ELSE '' END
    ) AS user_tag

FROM dim_users u
LEFT JOIN consumption_tags c ON u.user_id = c.user_id
LEFT JOIN activity_tags a ON u.user_id = a.user_id
LEFT JOIN category_tags ct ON u.user_id = ct.user_id AND ct.category_rank = 1;

-- 用户标签分布统计
SELECT
    consumption_level,
    activity_level,
    COUNT(*) AS user_count
FROM (
    SELECT
        COALESCE(c.consumption_level, '无消费') AS consumption_level,
        COALESCE(a.activity_level, '沉默') AS activity_level
    FROM dim_users u
    LEFT JOIN consumption_tags c ON u.user_id = c.user_id
    LEFT JOIN activity_tags a ON u.user_id = a.user_id
) t
GROUP BY consumption_level, activity_level
ORDER BY user_count DESC;
```

---

## 总结：ADB MySQL分析查询最佳实践

### 性能优化要点

| 优化点 | 方法 | 效果 |
|--------|------|------|
| 分区裁剪 | WHERE条件包含分区字段 | 减少扫描数据量 |
| 近似计算 | APPROX_COUNT_DISTINCT | 性能提升10倍+ |
| 聚簇索引 | 命中索引字段 | 减少IO |
| CTE结构 | 复杂查询拆分 | 提高可读性 |

### 常用分析模式

| 分析类型 | 核心技术 | 适用场景 |
|---------|---------|---------|
| 留存分析 | 自连接、DATEDIFF | 用户运营 |
| RFM分析 | NTILE分桶 | 用户分层 |
| 漏斗分析 | 条件聚合 | 转化优化 |
| 同环比分析 | LAG函数、自连接 | 趋势分析 |

---

## 执行计划分析

使用 `EXPLAIN` 命令可以查看分析查询的执行计划，帮助验证分区裁剪、索引使用、JOIN 优化是否生效：

```sql
-- 查看留存分析查询的执行计划
EXPLAIN WITH new_users AS (
    SELECT user_id, DATE(register_time) AS register_date
    FROM dim_users
    WHERE DATE_FORMAT(register_time, '%Y%m') = '202401'
)
SELECT
    register_date,
    COUNT(DISTINCT nu.user_id) AS cohort_size,
    COUNT(DISTINCT CASE WHEN DATEDIFF(DATE(active_time), register_date) = 1 THEN nu.user_id END) AS day1_retention
FROM new_users nu
LEFT JOIN dwd_user_active ua ON nu.user_id = ua.user_id
GROUP BY register_date;
```

**关键观察点**：
- **分区裁剪**：执行计划中应显示只扫描 `202401` 分区，而非全部分区
- **JOIN 优化**：检查 `dim_users` 和 `dwd_user_active` 的 JOIN 是否使用了分布键对齐
- **聚合优化**：确认 `COUNT(DISTINCT)` 是否使用了 `APPROX_COUNT_DISTINCT` 优化（如果启用了近似计算）

**性能监控**：
```sql
-- 使用 EXPLAIN ANALYZE 查看实际执行时间
EXPLAIN ANALYZE
SELECT
    DATE_FORMAT(order_time, '%Y-%m') AS month,
    COUNT(DISTINCT user_id) AS uv,
    SUM(amount) AS gmv
FROM fct_orders
WHERE DATE_FORMAT(order_time, '%Y%m') BETWEEN '202401' AND '202403'
GROUP BY DATE_FORMAT(order_time, '%Y-%m');
```

**优化建议**：
- 如果执行计划显示全分区扫描，检查 WHERE 条件是否包含分区字段
- 对于复杂的 CTE 查询，逐层检查每个 CTE 的执行计划
- 如果 JOIN 操作显示数据重分布，考虑调整分布键或使用 `/*+ MAPJOIN(table) */` hint
- 对于大规模聚合，优先使用 `APPROX_COUNT_DISTINCT` 而非 `COUNT(DISTINCT)`
| 路径分析 | 窗口函数 | 行为分析 |
| 画像标签 | CASE WHEN、聚合 | 精准营销 |