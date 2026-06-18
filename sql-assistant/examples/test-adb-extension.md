# ADB MySQL 扩展测试验证报告

## 测试目的

验证阿里云AnalyticDB for MySQL扩展是否正确实现，包括：
1. DDL生成是否包含DISTRIBUTED BY和PARTITION BY
2. 生成的SQL是否符合ADB语法规范
3. 分区裁剪优化是否正确应用
4. ADB特有函数是否正确使用

---

## 测试1：DDL生成测试

### 测试输入

```
/sql-gen 使用AnalyticDB MySQL创建订单事实表，包含订单ID、用户ID、订单时间、金额字段，按订单ID分布，按月分区
```

### 预期输出要点

- ✅ 包含 `DISTRIBUTED BY HASH(order_id)`
- ✅ 包含 `PARTITION BY VALUE(DATE_FORMAT(order_time, '%Y%m'))`
- ✅ 主键包含分区键 `order_time`
- ✅ 包含表注释和字段注释

### 参考正确输出

```sql
-- ============================================
-- 表名：fct_orders
-- 用途：订单事实表
-- 数据库：AnalyticDB for MySQL
-- 分布键：order_id
-- 分区策略：按月分区
-- ============================================

CREATE TABLE fct_orders (
    order_id BIGINT NOT NULL COMMENT '订单ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    order_time DATETIME NOT NULL COMMENT '订单时间',
    amount DECIMAL(18,2) COMMENT '订单金额',
    PRIMARY KEY (order_id, order_time)  -- 主键必须包含分区键
)
DISTRIBUTED BY HASH(order_id)  -- 按订单ID分布
PARTITION BY VALUE(DATE_FORMAT(order_time, '%Y%m'))  -- 按月分区
PARTITIONS 12
COMMENT '订单事实表';

-- 建议索引
-- 如需按用户查询优化，可创建聚簇索引：
-- CREATE CLUSTERED INDEX idx_cluster_user ON fct_orders(user_id, order_time);
```

### 测试结果

| 检查项 | 状态 | 说明 |
|--------|------|------|
| DISTRIBUTED BY | ⬜ 待验证 | 应包含分布键定义 |
| PARTITION BY VALUE | ⬜ 待验证 | 应包含分区策略 |
| 主键包含分区键 | ⬜ 待验证 | 主键应包含order_time |
| 索引建议 | ⬜ 待验证 | 应提供聚簇索引建议 |

---

## 测试2：分区裁剪查询测试

### 测试输入

```
/sql-gen 使用AnalyticDB MySQL查询2024年1月的销售数据，统计每个区域的销售额
```

### 预期输出要点

- ✅ WHERE条件包含分区裁剪：`DATE_FORMAT(order_time, '%Y%m') = '202401'`
- ✅ 使用正确的聚合函数
- ✅ 包含性能优化建议

### 参考正确输出

```sql
-- ============================================
-- 查询目的：各区域销售额统计
-- 目标数据库：AnalyticDB for MySQL
-- 优化策略：分区裁剪
-- ============================================

SELECT
    region_code,
    SUM(amount) AS total_amount,
    COUNT(*) AS order_count,
    APPROX_COUNT_DISTINCT(user_id) AS buyer_count  -- 近似去重，性能优化
FROM fct_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '202401'  -- 分区裁剪
  AND order_status = 'completed'
GROUP BY region_code
ORDER BY total_amount DESC;

-- 执行建议：
-- 1. ✅ 已使用分区裁剪，只扫描202401分区
-- 2. 建议在region_code字段创建二级索引
```

### 测试结果

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 分区裁剪条件 | ⬜ 待验证 | 应包含DATE_FORMAT分区条件 |
| 近似去重函数 | ⬜ 待验证 | 应使用APPROX_COUNT_DISTINCT |
| 性能建议 | ⬜ 待验证 | 应提供优化建议 |

---

## 测试3：聚簇索引创建测试

### 测试输入

```
/sql-gen 为fct_orders表创建聚簇索引，优化按用户维度的查询
```

### 预期输出要点

- ✅ 使用 `CREATE CLUSTERED INDEX` 语法
- ✅ 索引字段组合合理（user_id, order_time）
- ✅ 包含使用场景说明

### 参考正确输出

```sql
-- ============================================
-- 索引类型：聚簇索引（ADB特有）
-- 用途：优化用户维度查询性能
-- 适用场景：WHERE user_id = ? AND order_time >= ?
-- ============================================

CREATE CLUSTERED INDEX idx_cluster_user_time
ON fct_orders(user_id, order_time);

-- 说明：
-- 1. 聚簇索引使数据按索引顺序存储
-- 2. 适合查询模式：按用户+时间范围查询
-- 3. 可显著减少IO扫描量
```

### 测试结果

| 检查项 | 状态 | 说明 |
|--------|------|------|
| CLUSTERED INDEX语法 | ⬜ 待验证 | 应使用ADB特有语法 |
| 索引字段顺序 | ⬜ 待验证 | 应符合查询模式 |
| 使用场景说明 | ⬜ 待验证 | 应说明优化效果 |

---

## 测试4：INSERT OVERWRITE测试

### 测试输入

```
/sql-gen 使用AnalyticDB MySQL的INSERT OVERWRITE覆盖202401分区的订单数据
```

### 预期输出要点

- ✅ 使用 `INSERT OVERWRITE TABLE ... PARTITION(...)` 语法
- ✅ 分区条件正确
- ✅ 包含数据质量检查

### 参考正确输出

```sql
-- ============================================
-- 操作类型：分区覆盖写入
-- 目标表：fct_orders
-- 目标分区：202401
-- 注意：覆盖操作不可恢复，请确认后执行
-- ============================================

INSERT OVERWRITE TABLE fct_orders
PARTITION(DATE_FORMAT(order_time, '%Y%m') = '202401')
SELECT
    order_id,
    user_id,
    order_time,
    amount,
    status,
    CURRENT_TIMESTAMP AS etl_time
FROM source_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '202401';

-- 数据质量检查
SELECT
    COUNT(*) AS record_count,
    SUM(amount) AS total_amount
FROM fct_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '202401';
```

### 测试结果

| 检查项 | 状态 | 说明 |
|--------|------|------|
| INSERT OVERWRITE语法 | ⬜ 待验证 | 应使用ADB特有语法 |
| PARTITION定义 | ⬜ 待验证 | 分区条件应正确 |
| 质量检查 | ⬜ 待验证 | 应包含验证SQL |

---

## 测试5：留存分析查询测试

### 测试输入

```
/sql-gen 使用AnalyticDB MySQL计算新用户的7日留存率
```

### 预期输出要点

- ✅ 使用CTE结构
- ✅ 使用分区裁剪
- ✅ 可使用APPROX_COUNT_DISTINCT优化

### 参考正确输出

```sql
-- ============================================
-- 分析目的：新用户7日留存率
-- 数据库：AnalyticDB for MySQL
-- 优化：分区裁剪、近似去重
-- ============================================

WITH
new_users AS (
    SELECT
        user_id,
        DATE(register_time) AS register_date
    FROM dim_users
    WHERE DATE_FORMAT(register_time, '%Y%m') BETWEEN '202401' AND '202403'
),

user_activities AS (
    SELECT DISTINCT
        user_id,
        DATE(log_time) AS activity_date
    FROM fct_user_logs
    WHERE DATE_FORMAT(log_time, '%Y%m') BETWEEN '202401' AND '202403'
),

retention_calc AS (
    SELECT
        nu.register_date,
        APPROX_COUNT_DISTINCT(nu.user_id) AS new_user_count,
        APPROX_COUNT_DISTINCT(CASE
            WHEN DATEDIFF(ua.activity_date, nu.register_date) = 1
            THEN nu.user_id
        END) AS retention_day1,
        APPROX_COUNT_DISTINCT(CASE
            WHEN DATEDIFF(ua.activity_date, nu.register_date) = 7
            THEN nu.user_id
        END) AS retention_day7
    FROM new_users nu
    LEFT JOIN user_activities ua
        ON nu.user_id = ua.user_id
        AND DATEDIFF(ua.activity_date, nu.register_date) BETWEEN 1 AND 7
    GROUP BY nu.register_date
)

SELECT
    register_date,
    new_user_count,
    retention_day1,
    retention_day7,
    ROUND(retention_day1 * 100.0 / new_user_count, 2) AS retention_rate_day1,
    ROUND(retention_day7 * 100.0 / new_user_count, 2) AS retention_rate_day7
FROM retention_calc
ORDER BY register_date;
```

### 测试结果

| 检查项 | 状态 | 说明 |
|--------|------|------|
| CTE结构 | ⬜ 待验证 | 应使用WITH子句 |
| 分区裁剪 | ⬜ 待验证 | 应包含DATE_FORMAT条件 |
| 近似去重 | ⬜ 待验证 | 应使用APPROX_COUNT_DISTINCT |

---

## 测试6：维度表创建测试

### 测试输入

```
/sql-gen 使用AnalyticDB MySQL创建用户维度表，支持SCD Type 2
```

### 预期输出要点

- ✅ 包含DISTRIBUTED BY定义
- ✅ 包含SCD Type 2字段（effective_start_date, effective_end_date, is_current）
- ✅ 维度表可以不分区

### 参考正确输出

```sql
-- ============================================
-- 表名：dim_users
-- 用途：用户维度表（SCD Type 2）
-- 数据库：AnalyticDB for MySQL
-- 说明：支持历史变更追踪
-- ============================================

CREATE TABLE dim_users (
    user_sk BIGINT NOT NULL COMMENT '用户代理键',
    user_id BIGINT NOT NULL COMMENT '用户ID（自然键）',
    username VARCHAR(100) COMMENT '用户名',
    city VARCHAR(50) COMMENT '城市',
    user_level VARCHAR(20) COMMENT '用户等级',

    -- SCD Type 2 字段
    effective_start_date DATETIME COMMENT '生效开始时间',
    effective_end_date DATETIME COMMENT '生效结束时间',
    is_current BOOLEAN COMMENT '是否当前版本',

    PRIMARY KEY (user_sk)
)
DISTRIBUTED BY HASH(user_id)
COMMENT '用户维度表（SCD Type 2）';

-- 创建索引
CREATE INDEX idx_user_id ON dim_users(user_id);
CREATE INDEX idx_is_current ON dim_users(is_current);
```

### 测试结果

| 检查项 | 状态 | 说明 |
|--------|------|------|
| DISTRIBUTED BY | ⬜ 待验证 | 维度表也需要分布键 |
| SCD字段 | ⬜ 待验证 | 应包含历史版本字段 |
| 索引建议 | ⬜ 待验证 | 应提供查询优化索引 |

---

## 测试总结

### 测试统计

| 测试类型 | 测试项数 | 通过 | 失败 | 待验证 |
|---------|---------|------|------|--------|
| DDL生成 | 4 | - | - | 4 |
| 查询生成 | 3 | - | - | 3 |
| 索引创建 | 3 | - | - | 3 |
| ETL语句 | 3 | - | - | 3 |
| 分析查询 | 3 | - | - | 3 |
| 维度表 | 3 | - | - | 3 |
| **总计** | **19** | **0** | **0** | **19** |

### 验证方法

1. **手动测试**：在Claude Code中使用 `/sql-gen` 命令测试
2. **语法检查**：确保生成的SQL符合ADB语法
3. **最佳实践**：检查是否遵循ADB最佳实践

### 后续行动

- [ ] 执行手动测试
- [ ] 记录测试结果
- [ ] 修复发现的问题
- [ ] 更新文档

---

## 附录：ADB MySQL语法速查

### DDL语法

```sql
-- 创建分布式表
CREATE TABLE table_name (...)
DISTRIBUTED BY HASH(column)
PARTITION BY VALUE(expression)
PARTITIONS n;

-- 创建聚簇索引
CREATE CLUSTERED INDEX idx_name ON table_name(columns);

-- 创建二级索引
CREATE INDEX idx_name ON table_name(column);
```

### DML语法

```sql
-- 分区覆盖写入
INSERT OVERWRITE TABLE table_name
PARTITION(...)
SELECT ...;

-- 批量插入（推荐）
INSERT INTO table_name VALUES (...), (...), ...;
```

### 函数

```sql
-- 近似去重
APPROX_COUNT_DISTINCT(column)

-- 百分位
PERCENTILE(column, 0.5)

-- 分区键表达式
DATE_FORMAT(time_col, '%Y%m')
```

---

## 执行计划验证

使用 `EXPLAIN` 命令验证生成的 SQL 是否符合 ADB 优化要求：

```sql
-- 验证分区裁剪
EXPLAIN SELECT COUNT(*) FROM fct_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '202401';
-- 预期：执行计划显示只扫描 202401 分区

-- 验证聚簇索引使用
EXPLAIN SELECT * FROM fct_order_items
WHERE user_id = 12345 AND order_time >= '2024-01-01';
-- 预期：执行计划显示使用聚簇索引扫描

-- 验证分布键对齐 JOIN
EXPLAIN SELECT o.*, u.user_name
FROM fct_orders o
JOIN dim_users u ON o.user_id = u.user_id;
-- 预期：执行计划显示分布键对齐，无数据重分布
```

**测试检查清单**：

| 检查项 | 验证方法 | 预期结果 |
|--------|---------|---------|
| 分区裁剪 | EXPLAIN + WHERE 分区条件 | 只扫描目标分区 |
| 聚簇索引 | EXPLAIN + 索引字段查询 | 显示索引扫描 |
| 分布键对齐 | EXPLAIN + JOIN 分布键 | 无数据重分布 |
| 近似计算 | 对比 COUNT DISTINCT vs APPROX | 性能提升 10x+ |

---

**测试文档版本**: v1.0
**创建时间**: 2026-06-07
**测试执行人**: 待填写