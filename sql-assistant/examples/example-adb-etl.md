# ADB MySQL ETL 示例

本文档提供阿里云AnalyticDB for MySQL的ETL场景示例，涵盖增量同步、全量覆盖、数据质量检查等常见场景。

---

## 示例1：订单数据日增量同步

### 业务场景

每日凌晨从业务库同步订单数据到ADB数仓，增量同步，T+1时效。

### ETL设计

```sql
-- ============================================
-- ETL作业：订单数据日增量同步
-- 调度时间：每日凌晨 02:00
-- 数据源：业务MySQL orders表
-- 目标表：ADB fct_orders
-- 同步策略：分区覆盖（INSERT OVERWRITE）
-- ============================================

-- Step 1: 检查源数据是否就绪
SELECT
    '源数据检查' AS check_item,
    COUNT(*) AS record_count,
    MIN(order_time) AS min_time,
    MAX(order_time) AS max_time
FROM source_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '${bizdate}';

-- Step 2: 使用 INSERT OVERWRITE 覆盖目标分区
-- ADB特有语法：比DELETE+INSERT性能更好
INSERT OVERWRITE TABLE fct_orders
PARTITION(DATE_FORMAT(order_time, '%Y%m') = '${bizdate}')
SELECT
    order_id,
    user_id,
    order_time,
    product_id,
    quantity,
    amount,
    status,
    CURRENT_TIMESTAMP AS etl_time
FROM source_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '${bizdate}';

-- Step 3: 数据质量校验
SELECT
    '目标数据校验' AS check_item,
    COUNT(*) AS record_count,
    SUM(amount) AS total_amount,
    COUNT(DISTINCT user_id) AS unique_users
FROM fct_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '${bizdate}';

-- Step 4: 数据一致性校验（源表vs目标表）
SELECT
    '一致性校验' AS check_item,
    src.count AS source_count,
    tgt.count AS target_count,
    src.count - tgt.count AS diff
FROM
    (SELECT COUNT(*) AS count FROM source_orders
     WHERE DATE_FORMAT(order_time, '%Y%m') = '${bizdate}') src,
    (SELECT COUNT(*) AS count FROM fct_orders
     WHERE DATE_FORMAT(order_time, '%Y%m') = '${bizdate}') tgt;
```

### 注意事项

| 事项 | 说明 |
|------|------|
| 使用INSERT OVERWRITE | ADB列存架构，UPDATE/DELETE性能差 |
| 分区覆盖 | 只覆盖目标分区，不影响历史数据 |
| 执行时机 | 业务低峰期（凌晨） |
| 数据校验 | 同步后立即校验数据质量 |

---

## 示例2：用户维度增量更新（SCD Type 2）

### 业务场景

用户维度表需要保留历史变更记录（SCD Type 2），每日检查用户属性变更并新增版本记录。

### ETL设计

```sql
-- ============================================
-- ETL作业：用户维度增量更新（SCD Type 2）
-- 调度时间：每日凌晨 03:00
-- 策略：
--   1. 关闭旧版本记录（is_current = FALSE）
--   2. 插入新版本记录（is_current = TRUE）
-- ============================================

-- Step 1: 创建临时表存放变更用户
CREATE TABLE IF NOT EXISTS tmp_user_changes (
    user_id BIGINT,
    username VARCHAR(100),
    email VARCHAR(100),
    city VARCHAR(50),
    user_level VARCHAR(20),
    change_type VARCHAR(20)  -- NEW/UPDATE
)
DISTRIBUTED BY HASH(user_id);

-- Step 2: 识别新增用户
INSERT INTO tmp_user_changes
SELECT
    u.user_id,
    u.username,
    u.email,
    u.city,
    u.user_level,
    'NEW' AS change_type
FROM source_users u
LEFT JOIN dim_users d ON u.user_id = d.user_id AND d.is_current = TRUE
WHERE d.user_id IS NULL;

-- Step 3: 识别属性变更用户
INSERT INTO tmp_user_changes
SELECT
    u.user_id,
    u.username,
    u.email,
    u.city,
    u.user_level,
    'UPDATE' AS change_type
FROM source_users u
INNER JOIN dim_users d ON u.user_id = d.user_id AND d.is_current = TRUE
WHERE u.city != d.city
   OR u.user_level != d.user_level;

-- Step 4: 关闭旧版本（标记is_current = FALSE）
-- 注意：ADB不支持事务，需要分步执行
INSERT OVERWRITE TABLE dim_users
SELECT
    user_sk,
    user_id,
    username,
    email,
    city,
    user_level,
    effective_start_date,
    -- 如果是变更用户，设置结束时间为昨天
    CASE
        WHEN user_id IN (SELECT user_id FROM tmp_user_changes WHERE change_type = 'UPDATE')
        THEN DATE_SUB(CURRENT_DATE, INTERVAL 1 DAY)
        ELSE effective_end_date
    END AS effective_end_date,
    -- 如果是变更用户，设置为非当前版本
    CASE
        WHEN user_id IN (SELECT user_id FROM tmp_user_changes WHERE change_type = 'UPDATE')
        THEN FALSE
        ELSE is_current
    END AS is_current,
    register_time,
    last_update_time,
    CURRENT_TIMESTAMP AS etl_time
FROM dim_users
WHERE is_current = TRUE;

-- Step 5: 插入新版本记录
INSERT INTO dim_users
SELECT
    -- 生成新的代理键（使用序列或UUID）
    ROW_NUMBER() OVER (ORDER BY t.user_id) + 100000000 AS user_sk,
    t.user_id,
    t.username,
    t.email,
    t.city,
    t.user_level,
    CURRENT_DATE AS effective_start_date,
    '9999-12-31' AS effective_end_date,
    TRUE AS is_current,
    CURRENT_TIMESTAMP AS register_time,
    CURRENT_TIMESTAMP AS last_update_time,
    CURRENT_TIMESTAMP AS etl_time
FROM tmp_user_changes t;

-- Step 6: 清理临时表
TRUNCATE TABLE tmp_user_changes;

-- Step 7: 数据质量检查
SELECT
    'SCD检查' AS check_item,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_current THEN 1 ELSE 0 END) AS current_records,
    COUNT(DISTINCT user_id) AS unique_users
FROM dim_users;
```

---

## 示例3：销售数据聚合ETL

### 业务场景

从订单明细表聚合生成销售汇总表，支持多维分析。

### ETL设计

```sql
-- ============================================
-- ETL作业：销售数据日聚合
-- 调度时间：每日凌晨 04:00
-- 数据源：fct_order_items
-- 目标表：ads_sales_daily
-- ============================================

-- Step 1: 创建目标表（如果不存在）
CREATE TABLE IF NOT EXISTS ads_sales_daily (
    stat_date DATE NOT NULL,
    region_code VARCHAR(10),
    category_id BIGINT,
    order_count BIGINT COMMENT '订单数',
    buyer_count BIGINT COMMENT '买家数',
    quantity_sum BIGINT COMMENT '商品数量',
    amount_sum DECIMAL(18,2) COMMENT '销售金额',
    PRIMARY KEY (stat_date, region_code, category_id)
)
DISTRIBUTED BY HASH(stat_date)
PARTITION BY VALUE(DATE_FORMAT(stat_date, '%Y%m'))
PARTITIONS 12
COMMENT '销售日汇总表';

-- Step 2: 聚合计算并覆盖写入
INSERT OVERWRITE TABLE ads_sales_daily
PARTITION(DATE_FORMAT(stat_date, '%Y%m') = '${bizdate}')
SELECT
    DATE(order_time) AS stat_date,
    region_code,
    category_id,
    COUNT(DISTINCT order_id) AS order_count,
    APPROX_COUNT_DISTINCT(user_id) AS buyer_count,  -- 近似去重，性能优化
    SUM(quantity) AS quantity_sum,
    SUM(total_amount) AS amount_sum
FROM fct_order_items
WHERE DATE_FORMAT(order_time, '%Y%m') = '${bizdate}'
  AND order_status = 'completed'
GROUP BY DATE(order_time), region_code, category_id;

-- Step 3: 数据质量检查
SELECT
    '数据质量检查' AS check_item,
    COUNT(*) AS record_count,
    SUM(amount_sum) AS total_sales,
    SUM(order_count) AS total_orders
FROM ads_sales_daily
WHERE DATE_FORMAT(stat_date, '%Y%m') = '${bizdate}';

-- Step 4: 同环比计算（更新汇总表）
CREATE TABLE IF NOT EXISTS ads_sales_daily_yoy (
    stat_date DATE NOT NULL,
    region_code VARCHAR(10),
    category_id BIGINT,
    amount_sum DECIMAL(18,2),
    amount_sum_ly DECIMAL(18,2) COMMENT '去年同期',
    amount_sum_lm DECIMAL(18,2) COMMENT '上月同期',
    yoy_rate DECIMAL(10,4) COMMENT '同比增长率',
    mom_rate DECIMAL(10,4) COMMENT '环比增长率',
    PRIMARY KEY (stat_date, region_code, category_id)
)
DISTRIBUTED BY HASH(stat_date);

INSERT OVERWRITE TABLE ads_sales_daily_yoy
PARTITION(DATE_FORMAT(stat_date, '%Y%m') = '${bizdate}')
SELECT
    curr.stat_date,
    curr.region_code,
    curr.category_id,
    curr.amount_sum,
    ly.amount_sum AS amount_sum_ly,
    lm.amount_sum AS amount_sum_lm,
    (curr.amount_sum - ly.amount_sum) / ly.amount_sum AS yoy_rate,
    (curr.amount_sum - lm.amount_sum) / lm.amount_sum AS mom_rate
FROM ads_sales_daily curr
LEFT JOIN ads_sales_daily ly
    ON curr.region_code = ly.region_code
    AND curr.category_id = ly.category_id
    AND ly.stat_date = DATE_SUB(curr.stat_date, INTERVAL 1 YEAR)
LEFT JOIN ads_sales_daily lm
    ON curr.region_code = lm.region_code
    AND curr.category_id = lm.category_id
    AND lm.stat_date = DATE_SUB(curr.stat_date, INTERVAL 1 MONTH)
WHERE DATE_FORMAT(curr.stat_date, '%Y%m') = '${bizdate}';
```

---

## 示例4：实时数据入库

### 业务场景

从Kafka实时接收用户行为日志，批量写入ADB。

### 批量写入设计

```sql
-- ============================================
-- 批量写入：用户行为日志
-- 写入频率：每分钟一次
-- 批量大小：5000-10000行/批
-- ============================================

-- 批量INSERT（推荐）
INSERT INTO fct_user_logs (
    log_id, log_time, user_id, session_id,
    event_type, event_name, event_params
) VALUES
    (1001, '2024-01-15 10:00:01', 10001, 'sess_001', 'click', 'view_product', '{"page": "detail"}'),
    (1002, '2024-01-15 10:00:02', 10002, 'sess_002', 'click', 'add_cart', '{"product_id": 123}'),
    (1003, '2024-01-15 10:00:03', 10003, 'sess_003', 'click', 'purchase', '{"order_id": 456}'),
    -- ... 每批5000-10000行
    (6000, '2024-01-15 10:00:59', 10500, 'sess_500', 'click', 'view_home', '{}');

-- 性能优化要点：
-- 1. 批量INSERT比单行INSERT快100倍+
-- 2. 推荐每批5000-10000行
-- 3. 避免频繁小批次写入
```

### 写入性能对比

| 写入方式 | 性能 | 推荐场景 |
|---------|------|---------|
| 单行INSERT | ~100行/秒 | ❌ 不推荐 |
| 批量INSERT（100行） | ~1万行/秒 | ⚠️ 次优 |
| 批量INSERT（5000行） | ~5万行/秒 | ✅ 推荐 |
| 批量INSERT（10000行） | ~8万行/秒 | ✅ 推荐 |
| 批量INSERT（50000行） | ~10万行/秒 | ✅ 大批量 |

---

## 示例5：历史数据回刷

### 业务场景

需要回刷过去12个月的历史数据，修复数据错误或补充新字段。

### 批量回刷设计

```sql
-- ============================================
-- 历史数据回刷
-- 策略：按月循环执行，避免一次性加载
-- ============================================

-- 回刷2023年全年数据（12个月）
-- 建议分月执行，每次一个月

-- 回刷202301月数据
INSERT OVERWRITE TABLE fct_orders
PARTITION(DATE_FORMAT(order_time, '%Y%m') = '202301')
SELECT
    order_id,
    user_id,
    order_time,
    product_id,
    quantity,
    amount,
    status,
    -- 新增字段
    CASE
        WHEN status = 'completed' THEN '已完成'
        WHEN status = 'cancelled' THEN '已取消'
        ELSE '其他'
    END AS status_name,
    CURRENT_TIMESTAMP AS etl_time
FROM source_orders_history
WHERE DATE_FORMAT(order_time, '%Y%m') = '202301';

-- 回刷202302月数据
INSERT OVERWRITE TABLE fct_orders
PARTITION(DATE_FORMAT(order_time, '%Y%m') = '202302')
SELECT ... FROM source_orders_history
WHERE DATE_FORMAT(order_time, '%Y%m') = '202302';

-- ... 依次执行每个月

-- 批量执行脚本（使用变量）
-- SET @month_list = '202301,202302,202303,...';
-- 循环执行
```

### 执行建议

| 建议 | 说明 |
|------|------|
| 分批执行 | 每次回刷1个月数据 |
| 低峰期执行 | 凌晨或周末 |
| 监控资源 | 关注CPU和IO使用率 |
| 检查点 | 每个月完成后检查数据质量 |

---

## 示例6：数据清理

### 业务场景

定期清理过期分区数据，释放存储空间。

### 清理设计

```sql
-- ============================================
-- 数据清理：删除过期分区
-- 策略：保留最近12个月数据
-- 执行频率：每月1日
-- ============================================

-- 查看过期分区
SELECT
    table_name,
    partition_name,
    partition_value,
    data_size
FROM information_schema.partitions
WHERE table_name = 'fct_user_logs'
  AND partition_value < DATE_FORMAT(DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH), '%Y%m%d');

-- 方式1：删除单个分区（推荐）
-- ADB 语法：DROP PARTITION (分区键列 = 分区值)，分区值需与 PARTITION BY VALUE 的 DATE_FORMAT 格式一致
ALTER TABLE fct_user_logs DROP PARTITION (log_time = '20230101');

-- 方式2：批量删除多个分区
-- 需要循环执行，每次删除一个分区
ALTER TABLE fct_user_logs DROP PARTITION (log_time = '20230102');

-- 方式3：INSERT OVERWRITE覆盖（替代DELETE）
-- 将需要保留的数据写入新表，然后重命名
CREATE TABLE fct_user_logs_new AS SELECT * FROM fct_user_logs WHERE 1=0;

INSERT INTO fct_user_logs_new
SELECT * FROM fct_user_logs
WHERE DATE_FORMAT(log_time, '%Y%m%d') >= DATE_FORMAT(DATE_SUB(CURRENT_DATE, INTERVAL 90 DAY), '%Y%m%d');

-- 重命名表（需要停服）
ALTER TABLE fct_user_logs RENAME TO fct_user_logs_old;
ALTER TABLE fct_user_logs_new RENAME TO fct_user_logs;

-- 删除旧表
DROP TABLE fct_user_logs_old;
```

---

## 示例7：数据质量检查ETL

### 业务场景

在ETL流程中嵌入数据质量检查，确保数据准确性。

### 质量检查设计

```sql
-- ============================================
-- 数据质量检查
-- 检查时机：ETL完成后
-- 检查维度：完整性、准确性、一致性、时效性
-- ============================================

-- 创建质量检查结果表
CREATE TABLE IF NOT EXISTS dq_check_results (
    check_time DATETIME,
    table_name VARCHAR(100),
    check_type VARCHAR(50),
    check_item VARCHAR(200),
    check_result VARCHAR(20),  -- PASS/FAIL
    actual_value DECIMAL(20,2),
    threshold_value DECIMAL(20,2),
    error_message VARCHAR(500)
)
DISTRIBUTED BY HASH(check_time);

-- 检查1：数据完整性（记录数）
INSERT INTO dq_check_results
SELECT
    CURRENT_TIMESTAMP AS check_time,
    'fct_orders' AS table_name,
    '完整性' AS check_type,
    '日订单数' AS check_item,
    CASE WHEN COUNT(*) >= 50000 THEN 'PASS' ELSE 'FAIL' END AS check_result,
    COUNT(*) AS actual_value,
    50000 AS threshold_value,
    CASE WHEN COUNT(*) < 50000 THEN '订单数低于预期' ELSE NULL END AS error_message
FROM fct_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '${bizdate}';

-- 检查2：数据准确性（金额为正）
INSERT INTO dq_check_results
SELECT
    CURRENT_TIMESTAMP,
    'fct_orders',
    '准确性',
    '金额非负检查',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    0,
    CONCAT('发现', COUNT(*), '条金额为负的记录') AS error_message
FROM fct_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '${bizdate}'
  AND amount < 0;

-- 检查3：数据一致性（主键唯一）
INSERT INTO dq_check_results
SELECT
    CURRENT_TIMESTAMP,
    'fct_orders',
    '一致性',
    '主键唯一性',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*),
    0,
    CONCAT('发现', COUNT(*), '条主键重复记录') AS error_message
FROM (
    SELECT order_id, order_time, COUNT(*) AS cnt
    FROM fct_orders
    WHERE DATE_FORMAT(order_time, '%Y%m') = '${bizdate}'
    GROUP BY order_id, order_time
    HAVING COUNT(*) > 1
) t;

-- 检查4：数据时效性（数据新鲜度）
INSERT INTO dq_check_results
SELECT
    CURRENT_TIMESTAMP,
    'fct_orders',
    '时效性',
    '数据新鲜度',
    CASE WHEN MAX(etl_time) >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 2 HOUR) THEN 'PASS' ELSE 'FAIL' END,
    TIMESTAMPDIFF(HOUR, MAX(etl_time), CURRENT_TIMESTAMP),
    2,
    'ETL更新延迟超过2小时' AS error_message
FROM fct_orders
WHERE DATE_FORMAT(order_time, '%Y%m') = '${bizdate}';

-- 汇总检查结果
SELECT
    check_type,
    COUNT(*) AS total_checks,
    SUM(CASE WHEN check_result = 'PASS' THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN check_result = 'FAIL' THEN 1 ELSE 0 END) AS failed,
    CASE
        WHEN SUM(CASE WHEN check_result = 'FAIL' THEN 1 ELSE 0 END) = 0
        THEN '✅ 所有检查通过'
        ELSE '❌ 存在检查失败项'
    END AS overall_result
FROM dq_check_results
WHERE check_time >= CURRENT_DATE
GROUP BY check_type;

-- 告警：如果有失败项，发送通知
-- 可以集成钉钉、企业微信等通知
```

---

## 总结：ADB MySQL ETL最佳实践

### 核心原则

| 原则 | 说明 |
|------|------|
| 使用INSERT OVERWRITE | 替代DELETE+INSERT，性能更好 |
| 批量操作 | 每批5000-10000行 |
| 分区覆盖 | 只操作目标分区 |
| 数据校验 | ETL后立即检查 |
| 低峰执行 | 凌晨或周末 |

### 性能优化

| 优化点 | 方法 |
|--------|------|
| 写入性能 | 批量INSERT，每批5000+行 |
| 查询性能 | 分区裁剪、聚簇索引 |

---

## 执行计划分析

使用 `EXPLAIN` 命令可以查看 ETL 操作的执行计划，帮助验证分区裁剪、批量写入等优化是否生效：

```sql
-- 查看 INSERT OVERWRITE 的执行计划
EXPLAIN INSERT OVERWRITE TABLE fct_orders
PARTITION(DATE_FORMAT(order_time, '%Y%m') = '${bizdate}')
SELECT
    order_id,
    user_id,
    order_time,
    amount,
    status
FROM source_orders
WHERE DATE(order_time) = '${bizdate}';
```

**关键观察点**：
- **分区裁剪**：执行计划中应显示只扫描源表的 `${bizdate}` 分区
- **目标分区**：确认只写入目标分区，不影响其他分区数据
- **批量写入**：检查是否使用批量 INSERT 而非逐行插入

**性能监控**：
```sql
-- 查看 ETL 执行时间
SELECT
    table_name,
    check_time,
    check_type,
    CASE WHEN check_result = 'PASS' THEN '✅' ELSE '❌' END AS status
FROM dq_check_results
WHERE check_time >= CURRENT_DATE
ORDER BY check_time DESC;
```

**优化建议**：
- 如果 ETL 执行时间过长，检查源表分区裁剪是否生效
- 对于大数据量，考虑分批处理（每批 5000-10000 行）
- 使用 `EXPLAIN ANALYZE` 查看实际执行时间和资源消耗
| 近似计算 | APPROX_COUNT_DISTINCT |
| 避免操作 | 避免UPDATE/DELETE大批量数据 |