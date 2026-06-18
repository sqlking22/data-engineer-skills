# 示例：销售报表SQL开发完整流程

## 场景描述

业务需求：统计2024年Q1各区域销售情况，包含销售额、订单量、客单价、同比增长率

## 阶段1：SQL生成

**输入**：
```
/sql-gen 使用AnalyticDB MySQL语法，统计2024年Q1各区域的销售额、订单量、客单价，
         计算同比增长率（对比2023年Q1），只包含已完成订单，按销售额降序排列
```

**输出**：
```sql
-- ============================================
-- 查询目的：统计2024年Q1各区域销售情况及同比增长
-- 目标数据库：AnalyticDB MySQL
-- 生成时间：2025-03-17
-- ============================================

WITH q1_2024 AS (
    -- 2024年Q1销售数据
    SELECT
        region_code,
        region_name,
        COUNT(DISTINCT order_id) AS order_count,
        SUM(total_amount) AS sales_amount,
        AVG(total_amount) AS avg_order_value
    FROM orders
    WHERE order_date >= '2024-01-01'
        AND order_date < '2024-04-01'
        AND status = 'completed'
    GROUP BY region_code, region_name
),

q1_2023 AS (
    -- 2023年Q1销售数据
    SELECT
        region_code,
        SUM(total_amount) AS sales_amount
    FROM orders
    WHERE order_date >= '2023-01-01'
        AND order_date < '2023-04-01'
        AND status = 'completed'
    GROUP BY region_code
)

SELECT
    a.region_code AS 区域编码,
    a.region_name AS 区域名称,
    a.order_count AS 订单量,
    ROUND(a.sales_amount, 2) AS 销售总额,
    ROUND(a.avg_order_value, 2) AS 平均客单价,
    ROUND(b.sales_amount, 2) AS 去年同期销售额,
    CASE
        WHEN b.sales_amount > 0 THEN
            ROUND((a.sales_amount - b.sales_amount) * 100.0 / b.sales_amount, 2)
        ELSE NULL
    END AS 同比增长率
FROM q1_2024 a
LEFT JOIN q1_2023 b ON a.region_code = b.region_code
ORDER BY a.sales_amount DESC;

-- ============================================
-- 执行建议：
-- ============================================
-- 1. 建表时通过内联 INDEX 指定过滤字段（ADB 不支持独立 CREATE INDEX）：
--    CREATE TABLE orders (
--        order_id     BIGINT,
--        order_date   DATE,
--        status       VARCHAR(32),
--        region_code  VARCHAR(32),
--        region_name  VARCHAR(64),
--        total_amount DECIMAL(18,2),
--        PRIMARY KEY (order_id, order_date),
--        INDEX idx_orders_date(order_date),
--        INDEX idx_orders_status(status),
--        INDEX idx_orders_region(region_code),
--        CLUSTERED KEY ck_orders_region(region_code)
--    )
--    DISTRIBUTED BY HASH(order_id)
--    PARTITION BY VALUE(DATE_FORMAT(order_date, '%Y%m')) LIFECYCLE 36;

-- 2. 预计扫描行数：2024年Q1订单数（假设50万单）

-- 3. 预期执行时间：分区裁剪+索引命中 < 500ms，无索引 3-5秒
```

---

## 阶段2：SQL审查

**输入**：
```
/sql-review [上一步生成的SQL]
```

**输出摘要**：

| 维度 | 评分 | 状态 |
|------|------|------|
| 性能优化 | 8/10 | 🟢 良好 |
| 代码可读性 | 9/10 | 🟢 良好 |
| 健壮性 | 8/10 | 🟢 良好 |
| 安全性 | 10/10 | 🟢 良好 |
| **综合评分** | **8.8/10** | - |

**发现的问题**：
- 🟢 无严重问题
- 🟡 警告：CTE `q1_2023` 可能被多次引用时重复计算（当前场景无此问题）
- 🟢 建议：可考虑使用窗口函数一次性计算多年数据（更灵活）

---

## 阶段3：执行计划分析

**输入**：
```
/sql-explain
[粘贴 AnalyticDB MySQL EXPLAIN ANALYZE 结果]
```

**执行计划（简化）**：
```
-> Limit: 50 row(s)
    -> Sort: a.sales_amount DESC, limit input: 50 row(s) per Worker
        -> Hash join
            -> Table scan on a  (过滤条件: order_date in [2024-01-01, 2024-04-01))
                 Actual time: 245.3..389.2  Rows: 50  Partitions: 3
            -> Hash
                -> Table scan on b  (过滤条件: order_date in [2023-01-01, 2023-04-01))
                     Actual time: 180.1..289.5  Rows: 50  Partitions: 3
Peak memory: 24 MB
Total elapsed time: 389.5 ms
```

**分析结果摘要**：

| 指标 | 数值 | 评级 |
|------|------|------|
| 总执行时间 | 389.5 ms | 🟢 良好 |
| 分区裁剪 | 命中6个分区（Q1×2年） | 🟢 优秀 |
| Worker并行度 | 16 | 🟢 良好 |
| 峰值内存 | 24 MB | 🟢 良好 |

**关键发现**：
- 🟢 分区裁剪生效，仅扫描 Q1 两年共6个月分区，避免全表扫描
- 🟡 两次 orders 表扫描可优化（考虑汇总表缓存季度数据，减少重复聚合）
- 🟢 Hash Join 选择正确，适合两张聚合后的小结果集

**优化建议**：
```sql
-- AnalyticDB MySQL 不支持物化视图与 REFRESH MATERIALIZED VIEW，
-- 改为普通结果表 + 定时 ETL 任务（DataWorks 调度）每日刷新。

-- 1. 建立季度销售汇总结果表（含分布键/分区键的主键）
CREATE TABLE ads_quarterly_sales (
    quarter_code   VARCHAR(6)   COMMENT '季度编码 YYYYQ1',
    quarter_start  DATE         COMMENT '季度首日',
    region_code    VARCHAR(32)  COMMENT '区域编码',
    region_name    VARCHAR(64)  COMMENT '区域名称',
    order_count    BIGINT       COMMENT '订单数',
    sales_amount   DECIMAL(18,2) COMMENT '销售额',
    PRIMARY KEY (quarter_code, region_code),
    CLUSTERED KEY ck_quarter_region(quarter_code, region_code)
)
DISTRIBUTED BY HASH(region_code)
PARTITION BY VALUE(quarter_code) LIFECYCLE 12;

-- 2. 定时 ETL（每日凌晨刷新当前季度，可覆盖历史季度幂等写入）
INSERT OVERWRITE ads_quarterly_sales
SELECT
    CONCAT(DATE_FORMAT(order_date, '%Y'), 'Q', QUARTER(order_date)) AS quarter_code,
    CAST(DATE_FORMAT(DATE_SUB(order_date, DAY(order_date) - 1), '%Y-%m-%d') AS DATE) AS quarter_start,
    region_code,
    region_name,
    COUNT(DISTINCT order_id) AS order_count,
    SUM(total_amount) AS sales_amount
FROM orders
WHERE status = 'completed'
GROUP BY
    CONCAT(DATE_FORMAT(order_date, '%Y'), 'Q', QUARTER(order_date)),
    CAST(DATE_FORMAT(DATE_SUB(order_date, DAY(order_date) - 1), '%Y-%m-%d') AS DATE),
    region_code,
    region_name;
```

---

## 完整开发流程总结

```
需求理解 (2分钟)
    │
    ▼
SQL生成 /sql-gen (30秒)
    │
    ▼
SQL审查 /sql-review (1分钟)
    │ ← 8.8/10分，无需修改
    ▼
测试环境执行 + EXPLAIN (2分钟)
    │
    ▼
执行计划分析 /sql-explain (1分钟)
    │ ← 389ms，性能达标
    ▼
生产部署
    │
    ▼
监控运行情况
```

**总耗时**：约6-7分钟完成一个复杂报表SQL的开发和优化

**对比传统方式**：
| 步骤 | 传统方式 | AI辅助 | 节省时间 |
|------|----------|--------|----------|
| SQL编写 | 15分钟 | 30秒 | 97% |
| 代码审查 | 10分钟 | 1分钟 | 90% |
| 性能优化 | 20分钟 | 3分钟 | 85% |
| **总计** | **45分钟** | **6.5分钟** | **85%** |
