# SQL 开发规范与标准参考

> 本文件聚焦 SQL 编写的**通用规范**（命名 / 格式 / 注释 / 反模式速查 / 性能 checklist）。
> 方言详解：[AnalyticDB MySQL](adb-mysql-guide.md) · [MaxCompute](maxcompute-guide.md)
> 反模式详解与踩坑教训：[best-practices.md](best-practices.md)

## 目录

1. [SQL 编写规范](#sql-编写规范)
2. [ADB MySQL 与 MaxCompute 函数速查](#adb-mysql-与-maxcompute-函数速查)
3. [性能优化 checklist](#性能优化-checklist)
4. [常见反模式](#常见反模式)

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
    o.order_id,o.user_id,
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
| 空值处理 | `COALESCE(a,b)` / `IFNULL` | `COALESCE(a,b)` / `NVL(a,b)` | |

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

> ADB 的分布键对齐、分区裁剪、MaxCompute 的 MAPJOIN 等引擎特定优化，见对应方言文档：[adb-mysql-guide.md](adb-mysql-guide.md) · [maxcompute-guide.md](maxcompute-guide.md)。

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

> 以上为反模式速查。每个反模式的「为什么」、ADB 跨分布键 JOIN、COUNT(DISTINCT) 滥用等正反例详解，见 [best-practices.md](best-practices.md)。
