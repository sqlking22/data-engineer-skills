---
name: sql-assistant-best-practices
description: |
  SQL 开发最佳实践 - 团队经验沉淀，包含 SQL 写法正反例、ADB vs MaxCompute 语法差异、性能调优。
  触发词：SQL、最佳实践、避坑指南、SQL写法、SQL规范、性能调优、ADB MySQL、MaxCompute。
---

# SQL 开发最佳实践

> 本文沉淀团队在 SQL 开发阶段的实战经验，配套 [SKILL.md](../SKILL.md) 一起使用。
> 详细的方言规范见 [adb-mysql-guide.md](adb-mysql-guide.md) 与 [maxcompute-guide.md](maxcompute-guide.md)；SQL 通用规范见 [sql-standards.md](sql-standards.md)。

## 1. 核心原则速查

| # | 核心原则 | 说明 |
|---|---------|------|
| 1 | **明确数据库方言** | 写 SQL 前必须确定是 ADB MySQL 还是 MaxCompute |
| 2 | **避免 SELECT *** | 只查询需要的字段，减少网络和计算开销 |
| 3 | **优先使用 CTE** | 复杂查询用 CTE 代替嵌套子查询，可读性更好 |
| 4 | **分区裁剪必带** | WHERE 必须带分区字段，否则全表扫描 |
| 5 | **大表 JOIN 必优化** | 大表 JOIN 必须有分布键关联或 MAPJOIN |
| 6 | **NULL 处理明确** | 关键字段用 `COALESCE/NVL` 显式处理 |
| 7 | **注释完整** | 关键 SQL 必带注释（作者、目的、修改时间） |
| 8 | **测试覆盖** | 复杂 SQL 必须有测试用例和性能基线 |

## 2. 反模式与避坑指南

### ❌ 反例 1：SELECT * + 全表扫描

```sql
-- 错误：查所有字段，无分区条件
SELECT *
FROM orders;
```

✅ 正例：

```sql
-- 正确：只查需要的字段，带分区条件
SELECT
    order_id,
    user_id,
    amount,
    order_time
FROM orders
WHERE pt = '${bizdate}'
  AND status = 'paid';
```

💡 **为什么**：
- `SELECT *` 浪费 I/O 和网络带宽
- 无分区条件触发全表扫描，可能扫描 T 级数据
- 上百倍性能差异

---

### ❌ 反例 2：嵌套子查询（可读性差）

```sql
SELECT
    o.order_id,
    o.amount,
    (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.order_id) AS item_count,
    (SELECT user_name FROM users u WHERE u.user_id = o.user_id) AS user_name,
    (SELECT category_name FROM categories c
     JOIN products p ON c.category_id = p.category_id
     WHERE p.product_id IN (SELECT product_id FROM order_items WHERE order_id = o.order_id)
     LIMIT 1) AS category_name
FROM orders o
WHERE o.pt = '${bizdate}';
```

✅ 正例：

```sql
-- 使用 CTE（Common Table Expression）替代嵌套子查询
WITH order_items_agg AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        MAX(product_id) AS sample_product_id  -- 简化：取一个代表商品
    FROM order_items
    WHERE pt = '${bizdate}'
    GROUP BY order_id
),
product_category AS (
    SELECT
        oi.order_id,
        MAX(c.category_name) AS category_name  -- 简化：取一个代表类目
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN categories c ON p.category_id = c.category_id
    WHERE oi.pt = '${bizdate}'
    GROUP BY oi.order_id
)
SELECT
    o.order_id,
    o.amount,
    oi.item_count,
    u.user_name,
    pc.category_name
FROM orders o
LEFT JOIN order_items_agg oi ON o.order_id = oi.order_id
LEFT JOIN users u ON o.user_id = u.user_id
LEFT JOIN product_category pc ON o.order_id = pc.order_id
WHERE o.pt = '${bizdate}';
```

💡 **为什么**：
- 嵌套子查询：3 层以上基本无法读懂
- CTE：每一步意图清晰，可单独调试
- 性能：CTE 更容易被优化器识别为可并行执行

---

### ❌ 反例 3：NULL 处理不当

```sql
-- 错误：NULL 参与算术运算，结果可能不符合预期
SELECT
    order_id,
    amount - discount AS final_amount,  -- 如果 discount 是 NULL，结果是 NULL
    amount * 0.1 AS tax                  -- NULL * 0.1 = NULL
FROM orders;
```

✅ 正例：

```sql
-- 正确：显式处理 NULL
SELECT
    order_id,
    COALESCE(amount, 0) - COALESCE(discount, 0) AS final_amount,  -- ADB MySQL
    -- NVL(amount, 0) - NVL(discount, 0) AS final_amount,         -- MaxCompute
    COALESCE(amount, 0) * 0.1 AS tax
FROM orders
WHERE pt = '${bizdate}';
```

💡 **为什么**：
- NULL 参与算术运算结果是 NULL（不是 0！）
- 不显式处理会导致聚合时整列被吞掉
- `COALESCE`（ADB MySQL）和 `NVL`（MaxCompute）语法不同

---

### ❌ 反例 4：跨分布键 JOIN（ADB MySQL 性能灾难）

```sql
-- 错误：JOIN 键不是分布键，导致数据重分布
SELECT
    o.order_id,
    u.user_name,
    u.user_level
FROM orders o  -- 分布键：order_id
JOIN users u ON o.city_id = u.city_id  -- ❌ 关联字段是 city_id，不是分布键
WHERE o.pt = '${bizdate}';
```

✅ 正例：

```sql
-- 正确 1：JOIN 键使用两表的分布键
SELECT
    o.order_id,
    u.user_name,
    u.user_level
FROM orders o  -- 分布键：order_id
JOIN users u ON o.user_id = u.user_id  -- ✅ users 分布键也是 user_id
WHERE o.pt = '${bizdate}';

-- 正确 2：小表用广播 JOIN（ADB 用 BROADCAST_JOIN；MaxCompute 用 MAPJOIN）
SELECT /*+ BROADCAST_JOIN(u) */
    o.order_id,
    u.user_name,
    u.user_level
FROM orders o
JOIN dim_city u ON o.city_id = u.city_id  -- u 是小维度表
WHERE o.pt = '${bizdate}';
```

💡 **为什么**：
- ADB MySQL 是分布式数据库，JOIN 时如果关联键不是分布键，会触发数据重分布（Shuffle），性能急剧下降
- 大表 JOIN 关联键必须是分布键，或者把小表广播到所有节点
- 不当的 JOIN 可能让查询慢 100 倍

---

### ❌ 反例 5：函数导致索引失效

```sql
-- 错误：对索引字段使用函数，导致索引失效
SELECT *
FROM orders
WHERE DATE(created_at) = '2024-01-15'  -- DATE() 函数让 created_at 索引失效
  AND pt = '20240115';

-- 错误：LIKE 前缀模糊查询
SELECT *
FROM orders
WHERE order_id LIKE '%2024%'  -- 前缀 % 导致索引失效
  AND pt = '20240115';
```

✅ 正例：

```sql
-- 正确：避免在索引字段上使用函数
SELECT *
FROM orders
WHERE created_at >= '2024-01-15'
  AND created_at < '2024-01-16'  -- 范围查询，索引生效
  AND pt = '20240115';

-- 正确：LIKE 后缀模糊查询
SELECT *
FROM orders
WHERE order_id LIKE '2024%'  -- 后缀 %，索引生效
  AND pt = '20240115';
```

💡 **为什么**：
- 索引字段上使用函数会导致全表扫描
- LIKE 前缀模糊（'%xxx'）无法使用 B-Tree 索引
- 性能差异：秒级 vs 分钟级

---

### ❌ 反例 6：UNION 代替 UNION ALL

```sql
-- 错误：UNION 会去重，性能差
SELECT order_id FROM orders_2023
UNION
SELECT order_id FROM orders_2024;
```

✅ 正例：

```sql
-- 正确：UNION ALL 不去重，性能高
SELECT order_id FROM orders_2023
UNION ALL
SELECT order_id FROM orders_2024;

-- 如果确实需要去重，在外层加 DISTINCT
SELECT DISTINCT order_id FROM (
    SELECT order_id FROM orders_2023
    UNION ALL
    SELECT order_id FROM orders_2024
) t;
```

💡 **为什么**：
- UNION 内部会去重（隐式 DISTINCT + 排序）
- UNION ALL 直接合并，性能高 5-10 倍
- 已知不重复就用 UNION ALL

---

### ❌ 反例 7：COUNT(DISTINCT) 滥用

```sql
-- 错误：在多个维度上分别 COUNT(DISTINCT)，导致数据重复计算
SELECT
    user_id,
    COUNT(DISTINCT order_id) AS user_order_count,
    COUNT(DISTINCT product_id) AS user_product_count,
    COUNT(DISTINCT DATE(order_time)) AS user_active_days
FROM order_items
WHERE pt BETWEEN '${start_date}' AND '${end_date}'
GROUP BY user_id;
```

✅ 正例：

```sql
-- 正确：使用近似函数（适用于大宽表）
SELECT
    user_id,
    COUNT(DISTINCT order_id) AS user_order_count,
    COUNT(DISTINCT product_id) AS user_product_count,
    -- 使用 APPROX_COUNT_DISTINCT 提升性能
    APPROX_COUNT_DISTINCT(DATE(order_time)) AS user_active_days_approx
FROM order_items
WHERE pt BETWEEN '${start_date}' AND '${end_date}'
GROUP BY user_id;
```

💡 **为什么**：
- 精确去重（COUNT DISTINCT）需要大量内存
- 近似去重（APPROX_COUNT_DISTINCT / HyperLogLog）性能高，误差 < 1%
- 大宽表上性能差异巨大

---

## 3. SQL 示例

### 3.1 销售分析核心查询（多维度聚合）

```sql
-- 销售分析：按地区 + 品类 + 日期聚合
WITH daily_sales AS (
    SELECT
        DATE(o.created_at) AS sale_date,
        o.user_id,
        oi.product_id,
        oi.item_amount
    FROM dwd_trade_order_detail o
    JOIN dwd_trade_order_item oi ON o.order_id = oi.order_id
    WHERE o.pt BETWEEN '${start_date}' AND '${end_date}'
      AND o.status = 'paid'
),
product_category AS (
    SELECT
        product_id,
        category_id
    FROM dim_product
    WHERE is_current = TRUE
),
region_mapping AS (
    SELECT
        user_id,
        city_code,
        region_name
    FROM dim_user u
    JOIN dim_city c ON u.city_code = c.city_code
    WHERE u.is_current = TRUE
)
SELECT
    d.sale_date,
    r.region_name,
    pc.category_id,
    COUNT(DISTINCT d.user_id) AS buyer_count,
    COUNT(DISTINCT d.order_id) AS order_count,
    SUM(d.item_amount) AS gmv
FROM daily_sales d
LEFT JOIN product_category pc ON d.product_id = pc.product_id
LEFT JOIN region_mapping r ON d.user_id = r.user_id
WHERE d.sale_date BETWEEN '${start_date}' AND '${end_date}'
GROUP BY d.sale_date, r.region_name, pc.category_id
ORDER BY d.sale_date DESC, gmv DESC;
```

### 3.2 用户留存分析（窗口函数）

```sql
-- 计算用户次日、7日、30日留存
WITH user_first_active AS (
    SELECT
        user_id,
        MIN(DATE(created_at)) AS first_active_date
    FROM dwd_trade_order_detail
    WHERE pt BETWEEN '${start_date}' AND DATE_FORMAT(DATE_ADD('${start_date}', INTERVAL 60 DAY), '%Y%m%d')
    GROUP BY user_id
),
user_daily_active AS (
    SELECT DISTINCT
        user_id,
        DATE(created_at) AS active_date
    FROM dwd_trade_order_detail
    WHERE pt BETWEEN '${start_date}' AND DATE_FORMAT(DATE_ADD('${start_date}', INTERVAL 60 DAY), '%Y%m%d')
),
retention_calculation AS (
    SELECT
        ufa.first_active_date,
        uda.user_id,
        uda.active_date,
        DATEDIFF(uda.active_date, ufa.first_active_date) AS days_since_first
    FROM user_first_active ufa
    JOIN user_daily_active uda ON ufa.user_id = uda.user_id
)
SELECT
    first_active_date,
    COUNT(DISTINCT CASE WHEN days_since_first = 0 THEN user_id END) AS d0_count,
    COUNT(DISTINCT CASE WHEN days_since_first = 1 THEN user_id END) AS d1_count,
    COUNT(DISTINCT CASE WHEN days_since_first = 7 THEN user_id END) AS d7_count,
    COUNT(DISTINCT CASE WHEN days_since_first = 30 THEN user_id END) AS d30_count,
    -- 留存率
    ROUND(COUNT(DISTINCT CASE WHEN days_since_first = 1 THEN user_id END) * 100.0 /
          NULLIF(COUNT(DISTINCT CASE WHEN days_since_first = 0 THEN user_id END), 0), 2) AS d1_retention
FROM retention_calculation
GROUP BY first_active_date
ORDER BY first_active_date DESC;
```

### 3.3 ADB MySQL 分布键设计示例

```sql
-- 订单事实表：分布键选择
-- 原则：高基数 + 常用 JOIN 字段 + 避免数据倾斜
CREATE TABLE dwd_trade_order_detail (
    order_id BIGINT NOT NULL,
    user_id BIGINT,
    product_id BIGINT,
    date_key INT,
    amount DECIMAL(18,2),
    pt VARCHAR(8),
    PRIMARY KEY (order_id, pt)
)
-- 关键：分布键选择 order_id，因为：
-- 1. 高基数（几乎唯一）
-- 2. 是最常用的 JOIN 字段
-- 3. 避免按日期分布（会导致数据倾斜）
DISTRIBUTED BY HASH(order_id)
PARTITION BY VALUE(DATE_FORMAT(STR_TO_DATE(pt, '%Y%m%d'), '%Y%m'))
LIFECYCLE 365;

-- 维度表：通常按主键分布
CREATE TABLE dim_user (
    user_sk BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    ...
)
DISTRIBUTED BY HASH(user_sk);
```

### 3.4 MaxCompute MAPJOIN 示例

```sql
-- MaxCompute 小表 JOIN（MAPJOIN 提示）
SELECT /*+ MAPJOIN(dim_city) */
    o.order_id,
    o.user_id,
    c.city_name,
    c.province_name,
    o.amount
FROM dwd_trade_order o
LEFT JOIN dim_city c ON o.city_code = c.city_code
WHERE o.pt = '${bizdate}';
```

## 4. 经验教训

### 踩坑 #1：分布键选择错误导致数据倾斜

**场景**：订单表按 `pt` 分布（按日期），但 90% 数据集中在最近 7 天，少数节点压力巨大。
**原因**：分布键应该选高基数均匀分布的字段（如 `order_id`），而不是时间字段。
**解决**：改用 `order_id` 作为分布键，重新建表。
**预防**：分布键三原则 - 高基数 + 均匀分布 + 常用 JOIN 字段。

### 踩坑 #2：日期格式不一致导致 WHERE 失效

**场景**：pt 字段在 ODS 是 '2024-01-15'，在 DWD 是 '20240115'，WHERE 条件写了 `pt = '2024-01-15'` 但 DWD 没数据。
**原因**：ETL 时格式转换了，但下游不知道。
**解决**：统一使用 YYYYMMDD 字符串格式（全链路一致）。
**预防**：在分层命名规范中明确 pt 格式，所有层保持一致。

### 踩坑 #3：大表上做 FULL OUTER JOIN

**场景**：2 张各 10 亿的表做 FULL OUTER JOIN，任务跑了 3 小时没结果。
**原因**：FULL OUTER JOIN 在分布式数据库上极慢。
**解决**：改为 LEFT JOIN + UNION ALL + RIGHT JOIN，分两步做。
**预防**：避免 FULL OUTER JOIN，改用 UNION 模式或拆成多个 LEFT/RIGHT JOIN。

### 踩坑 #4：未指定数据库方言，AI 生成错误的 SQL

**场景**：让 AI 写 SQL，未指定是 ADB MySQL，结果生成了 MySQL 8.0 的窗口函数语法，但 ADB MySQL 5.7 不支持。
**原因**：AI 默认按通用 MySQL 语法写。
**解决**：明确告诉 AI "使用 ADB MySQL 5.7 兼容语法"。
**预防**：所有 SQL 任务前置检查中必须明确数据库类型和版本。

### 踩坑 #5：分区字段未携带导致全表扫描

**场景**：跑一个看似简单的 SQL 却跑了 30 分钟，因为表是按月分区，WHERE 漏掉了 pt。
**原因**：分析师不知道表的分区键。
**解决**：在表注释中明确写"分区键：pt，格式 YYYYMMDD"。
**预防**：所有查询必须强制带 `pt = '${bizdate}'`，在代码审查中作为硬性要求。

## 5. 协作建议

### 5.1 与 AI 协作（使用 /sql-gen）

- **明确数据库**：在 prompt 中写明 "使用 ADB MySQL 5.7 语法" 或 "使用 MaxCompute 语法"
- **提供 DDL**：附上表结构，避免 AI 凭空想象字段
- **明确业务**：说明业务背景，避免 AI 写出的 SQL 与业务脱节
- **测试验证**：生成后必须测试，不能直接上线

### 5.2 Code Review 关注点

| 检查项 | 说明 |
|--------|------|
| 数据库方言 | 是否与目标库匹配 |
| 分区裁剪 | WHERE 是否带分区字段 |
| 索引利用 | 索引字段是否被函数包裹 |
| 性能估算 | 大表 JOIN、COUNT(DISTINCT) 是否合理 |
| NULL 处理 | 关键字段是否有 COALESCE/NVL |
| 注释完整 | 复杂 SQL 是否有作者、目的说明 |

### 5.3 性能调优建议

| 现象 | 优化方向 |
|------|---------|
| 查询慢 | 检查执行计划 → 确认分区裁剪 → 检查 JOIN 键 |
| 资源占用高 | 检查数据倾斜 → 调整分布键 |
| 任务超时 | 拆分任务并行执行 → 减少单任务数据量 |
| 频繁 OOM | 减少 COUNT(DISTINCT) → 用近似函数 |
| 索引失效 | 避免函数包裹 → 改写 WHERE 条件 |

---

**附录**：
- 详细规范：[sql-standards.md](sql-standards.md)
- SQL 生成器：[sql-generator.md](sql-generator.md)
- SQL 审查器：[sql-reviewer.md](sql-reviewer.md)
- 执行计划分析：[sql-explain.md](sql-explain.md)
