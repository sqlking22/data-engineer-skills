---
name: maxcompute-guide
description: |
  MaxCompute 方言知识库 - 阿里云大数据计算服务的 DDL/DML/函数/性能优化。
  触发词：MaxCompute、ODPS、MAPJOIN、分区裁剪、海量离线、动态分区。
---

# MaxCompute 方言知识库

> MaxCompute（原 ODPS）是阿里云自研的大数据计算服务，专为海量离线数据处理设计。
> SQL 编写通用规范（命名/格式/反模式）见 [sql-standards.md](sql-standards.md)；ADB MySQL 方言见 [adb-mysql-guide.md](adb-mysql-guide.md)。

## 目录

1. [概述](#概述)
2. [DDL 语法差异](#ddl-语法差异)
3. [DML 语法差异](#dml-语法差异)
4. [性能优化](#性能优化)
5. [最佳实践](#最佳实践)

---

## 概述

MaxCompute（原ODPS）是阿里云自主研发的大数据计算服务，专为海量数据处理设计。

**核心特点**：
- ✅ 海量数据处理能力
- ✅ 高性价比
- ✅ 分区表支持
- ⚠️ 不支持事务
- ⚠️ 有特有SQL语法

**适用场景**：海量离线处理（日志/埋点/行为日志/性能日志）。OLAP 数仓分析请用 AnalyticDB MySQL。

---

## DDL 语法差异

### 1. 创建分区表

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

### 2. 数据类型

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

---

## DML 语法差异

### 1. 查询语法

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

### 2. 函数差异

| 功能 | ADB MySQL | MaxCompute |
|------|-------|------------|
| 当前日期 | `CURDATE()` | `GETDATE()` |
| 日期格式化 | `DATE_FORMAT(d,f)` | `DATE_FORMAT(d,f)` |
| 字符串拼接 | `CONCAT(s1,s2)` | `CONCAT(s1,s2)` |
| 条件判断 | `IF(cond,a,b)` | `IF(cond,a,b)` / `CASE WHEN` |
| 分组连接 | `GROUP_CONCAT()` | `WM_CONCAT()` |
| 空值处理 | `COALESCE(a,b)` | `COALESCE(a,b)` / `NVL(a,b)` |

> ADB MySQL 与 MaxCompute 的完整函数对照见 [sql-standards.md](sql-standards.md) 函数速查表。

---

## 性能优化

### 1. 分区裁剪

```sql
-- ✅ 推荐：使用分区条件
SELECT * FROM orders
WHERE pt = '202401';

-- ❌ 避免：全表扫描
SELECT * FROM orders;
```

### 2. MAPJOIN优化

```sql
-- 小表JOIN使用MAPJOIN（小表放内存）
SELECT /*+ MAPJOIN(small_table) */ *
FROM large_table l
JOIN small_table s ON l.key = s.key;
```

### 3. 并行执行

```sql
-- 设置并行度
SET odps.sql.parallel.factor=10;

-- 设置Reducer数量
SET odps.sql.reducer.instances=100;
```

---

## 最佳实践

1. **必须使用分区**：MaxCompute 表必须有分区
2. **分区裁剪**：查询时必须包含分区条件
3. **生命周期管理**：设置合理的生命周期（LIFECYCLE n 天，超期回收）
4. **小文件合并**：避免产生大量小文件
5. **大表 JOIN**：小表用 `/*+ MAPJOIN(t) */` 放入内存，避免 Shuffle

---

## 参考资料

- [阿里云 MaxCompute 官方文档](https://help.aliyun.com/product/27748.html)
