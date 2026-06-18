---
name: modeling-assistant-best-practices
description: |
  数据建模最佳实践 - 团队经验沉淀，包含 OneData vs Kimball 取舍、命名反例、粒度选择、分层陷阱。
  触发词：数据建模、最佳实践、避坑指南、OneData、Kimball、命名规范、SCD策略。
---

# 数据建模最佳实践

> 本文沉淀团队在数据建模阶段的实战经验，配套 [SKILL.md](../SKILL.md) 一起使用。
> 强烈建议先阅读 [onedata-methodology.md](onedata-methodology.md) 了解自顶向下规划方法。

## 1. 核心原则速查

| # | 核心原则 | 说明 |
|---|---------|------|
| 1 | **先 OneData，后 Kimball** | 先做数据域划分和总线矩阵，再做表级设计 |
| 2 | **粒度先于一切** | 事实表设计前必须明确粒度（最细业务级别） |
| 3 | **维度一致性** | 同一维度（如用户）在所有业务过程必须一致 |
| 4 | **命名规范化** | 表名 `{layer}_{domain}_{entity}`，字段名 snake_case |
| 5 | **SCD 策略明确** | 默认 SCD Type 2，除非明确不需要历史 |
| 6 | **分层依赖单向** | ADS → DWS → DWD → ODS，禁止反向依赖 |
| 7 | **代理键优先** | 维度表使用 BIGINT 代理键，避免依赖自然键 |
| 8 | **公共模型复用** | 优先使用 dim_user / dim_date 等公共维度 |

## 2. 反模式与避坑指南

### ❌ 反例 1：命名随意

```sql
CREATE TABLE order_info_1;      -- 第一个版本？
CREATE TABLE orders_tmp;        -- 临时表混入数仓
CREATE TABLE v_order_data;      -- v 前缀、混用英文
CREATE TABLE ods_user_v2;       -- 版本号后缀
```

✅ 正例：

```sql
CREATE TABLE ods_trade_order;             -- ODS 层
CREATE TABLE dwd_trade_order_detail;       -- DWD 层
CREATE TABLE dws_trade_user_1d;            -- DWS 层（1天粒度）
CREATE TABLE ads_trade_sales_report;       -- ADS 层
CREATE TABLE dim_user;                     -- 维度层
```

💡 **为什么**：不规范命名会导致：
1. 团队成员看不懂表用途
2. 无法按表名归类
3. 跨系统对接时频繁出错
4. 重构时无法批量替换

---

### ❌ 反例 2：粒度混乱

```sql
-- 同一个事实表，混合不同粒度的度量
CREATE TABLE fct_orders (
    order_id BIGINT,
    -- 订单级度量
    order_amount DECIMAL,        -- 订单金额（订单级）
    -- 订单项级度量
    item_quantity INT,           -- 数量（订单项级）
    -- 用户级度量
    user_total_orders BIGINT,    -- 用户总订单数（用户级）
    -- 时间级度量
    daily_gmv DECIMAL            -- 当日 GMV（日级）
);
```

✅ 正例：

```sql
-- 订单项级事实表
CREATE TABLE fct_order_items (
    order_item_sk BIGINT PRIMARY KEY,
    order_id BIGINT,            -- 退化维度
    user_sk BIGINT,
    product_sk BIGINT,
    quantity INT,               -- 数量（订单项级）
    item_amount DECIMAL,        -- 金额（订单项级）
    -- 订单级/用户级/日级指标在 DWS 层通过聚合得到
);

-- 订单级 DWS 汇总表
CREATE TABLE dws_trade_order_1d (
    order_id BIGINT PRIMARY KEY,
    order_amount DECIMAL,
    item_count INT
);

-- 用户级 DWS 汇总表
CREATE TABLE dws_trade_user_1d (
    user_sk BIGINT,
    stat_date DATE,
    user_total_orders BIGINT
);
```

💡 **为什么**：粒度混乱会导致：
1. 同名字段在不同行重复，存储浪费
2. 跨粒度 SUM 时结果错误（如用户总订单数重复累加）
3. 下游不知道是直接使用还是需要去重

---

### ❌ 反例 3：维度属性散落

```sql
-- 事实表直接冗余了所有维度属性（违反规范化）
CREATE TABLE fct_order_items (
    order_item_sk BIGINT,
    order_id BIGINT,
    -- 用户表字段
    user_name VARCHAR,
    user_email VARCHAR,
    user_phone VARCHAR,
    user_level VARCHAR,
    -- 商品表字段
    product_name VARCHAR,
    product_brand VARCHAR,
    product_category VARCHAR,
    quantity INT,
    amount DECIMAL
);
```

✅ 正例：

```sql
-- 事实表只保留代理键
CREATE TABLE fct_order_items (
    order_item_sk BIGINT,
    user_sk BIGINT,           -- 关联到 dim_user
    product_sk BIGINT,        -- 关联到 dim_product
    date_key INT,             -- 关联到 dim_date
    order_id BIGINT,          -- 退化维度
    quantity INT,
    amount DECIMAL
);

-- 通过 JOIN 在查询时获取维度属性
SELECT
    u.user_level,
    p.product_category,
    SUM(f.amount) AS gmv
FROM fct_order_items f
JOIN dim_user u ON f.user_sk = u.user_sk AND u.is_current = TRUE
JOIN dim_product p ON f.product_sk = p.product_sk AND p.is_current = TRUE
GROUP BY u.user_level, p.product_category;
```

💡 **为什么**：冗余所有维度属性会导致：
1. 维度属性变更时需要更新所有事实表
2. 存储空间浪费（维度属性会被复制数亿次）
3. 难以保证一致性

例外情况：频繁查询的高基数属性可适度冗余（如 dim_date 的日期字段）

---

### ❌ 反例 4：跨层依赖

```sql
-- ADS 层直接读 ODS 层（跳过了 DWD、DWS）
CREATE TABLE ads_sales_report AS
SELECT * FROM ods_orders        -- ❌ 跨层依赖
WHERE pt = '${bizdate}';
```

✅ 正例：

```sql
-- ADS 层应该消费 DWS 层
CREATE TABLE ads_sales_report AS
SELECT
    dws.stat_date,
    dws.region,
    SUM(dws.gmv) AS gmv,
    COUNT(DISTINCT dws.user_sk) AS user_count
FROM dws_trade_user_1d dws
WHERE dws.pt = '${bizdate}'
GROUP BY dws.stat_date, dws.region;

-- DWS 层消费 DWD 层
-- DWD 层消费 ODS 层
-- 形成完整的数据流转链：ODS → DWD → DWS → ADS
```

💡 **为什么**：跨层依赖会导致：
1. ODS 表结构变化直接影响 ADS 报表
2. 无法保证数据质量（跳过中间层清洗）
3. 无法做公共指标沉淀

---

### ❌ 反例 5：SCD 策略混乱

```sql
-- 同一张维度表，不同字段用不同 SCD 策略，但没明确标识
CREATE TABLE dim_user (
    user_id BIGINT PRIMARY KEY,
    username VARCHAR,        -- 直接覆盖（实际是 SCD1）
    user_level VARCHAR,      -- 但又保留了历史（实际是 SCD2）
    city VARCHAR,            -- 又只保留最新
    -- 缺少 is_current, valid_from, valid_to 字段
);
```

✅ 正例：

```sql
-- 明确 SCD 策略，每个字段标注
CREATE TABLE dim_user (
    user_sk BIGINT PRIMARY KEY,                  -- 代理键
    user_id BIGINT NOT NULL,                     -- 自然键
    
    -- SCD Type 0：永不改变
    register_date DATE NOT NULL,
    
    -- SCD Type 2：保留历史
    username VARCHAR,
    email VARCHAR,
    user_level VARCHAR,
    city VARCHAR,
    
    -- SCD 2 元数据字段
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    is_current BOOLEAN DEFAULT TRUE,
    
    -- ADB 不支持 UNIQUE KEY，唯一性通过主键（user_sk）或数据质量规则保障
)
DISTRIBUTED BY HASH(user_sk);

-- 查询时通过 is_current 过滤获取当前版本
SELECT * FROM dim_user WHERE user_id = 1001 AND is_current = TRUE;

-- 查询历史某时间点
SELECT * FROM dim_user
WHERE user_id = 1001
  AND valid_from <= '2024-01-01'
  AND valid_to > '2024-01-01';
```

💡 **为什么**：SCD 策略混乱会导致：
1. 历史分析结果错误（取到错误版本）
2. 维度表无法支持时间维度分析
3. 跨业务过程维度不一致

---

### ❌ 反例 6：维度爆炸

```sql
-- 同一个维度被定义为多张表
CREATE TABLE dim_user;
CREATE TABLE dim_user_v1;        -- 版本1
CREATE TABLE dim_user_new;       -- 新版本
CREATE TABLE dim_users;          -- 加了 s
-- 下游不知道该用哪个
```

✅ 正例：

```sql
-- 只有一张 dim_user，通过 SCD 策略管理版本
-- 下游永远消费同一张表
CREATE TABLE dim_user (
    user_sk BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    -- SCD 2 字段管理历史
    valid_from DATE,
    valid_to DATE,
    is_current BOOLEAN
);

-- 如果需要做大幅重构（如字段重构），通过"新建表 + 视图兼容"过渡
CREATE VIEW dim_user_v1 AS SELECT * FROM dim_user;  -- 兼容视图
```

💡 **为什么**：维度爆炸会导致：
1. 跨业务过程无法做一致关联
2. 下游困惑到底用哪个
3. 维护成本 3x

---

## 3. SQL 示例

### 3.1 完整的 DWD 层 ETL 模板

```sql
-- ODS → DWD 的标准 ETL
INSERT OVERWRITE TABLE dwd_trade_order_detail
PARTITION (pt = '${bizdate}')
SELECT
    -- 维度外键（通过 JOIN 维表获取）
    d.date_key,
    u.user_sk,
    p.product_sk,
    
    -- 退化维度（直接从源表取）
    o.order_id,
    oi.order_item_id,
    
    -- 度量（订单项级）
    oi.quantity,
    oi.unit_price,
    oi.discount_amount,
    oi.item_amount AS total_amount,
    
    -- 业务时间
    o.created_at AS business_time,
    
    -- ETL 元数据
    CURRENT_TIMESTAMP AS etl_time,
    '${batch_id}' AS etl_batch_id
    
FROM (
    SELECT * FROM ods_trade_order
    WHERE pt = '${bizdate}' AND status != 'cancelled'
) o
JOIN (
    SELECT * FROM ods_trade_order_item
    WHERE pt = '${bizdate}'
) oi ON o.order_id = oi.order_id
LEFT JOIN dim_user u
    ON o.user_id = u.user_id AND u.is_current = TRUE
LEFT JOIN dim_product p
    ON oi.product_id = p.product_id AND p.is_current = TRUE
LEFT JOIN dim_date d
    ON DATE(o.created_at) = d.date_value;
```

### 3.2 完整的 DWS 层宽表 ETL 模板

```sql
-- DWD → DWS 宽表构建
INSERT OVERWRITE TABLE dws_trade_user_1d
PARTITION (pt = '${bizdate}')
SELECT
    dwd.user_sk,
    dwd.date_key,
    
    -- 原子指标：直接聚合
    SUM(dwd.total_amount) AS pay_amount_1d,
    COUNT(DISTINCT dwd.order_id) AS order_count_1d,
    COUNT(DISTINCT dwd.user_sk) AS pay_user_count_1d,
    
    -- 衍生指标
    CASE WHEN COUNT(DISTINCT dwd.order_id) > 0
         THEN SUM(dwd.total_amount) / COUNT(DISTINCT dwd.order_id)
         ELSE 0
    END AS arpu_1d,
    
    -- 7 天滚动指标（窗口函数）
    SUM(SUM(dwd.total_amount)) OVER (
        PARTITION BY dwd.user_sk
        ORDER BY dwd.date_key
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS pay_amount_7d,
    
    -- ETL 元数据
    CURRENT_TIMESTAMP AS etl_time
FROM dwd_trade_order_detail dwd
WHERE dwd.pt BETWEEN DATE_SUB('${bizdate}', 6) AND '${bizdate}'
GROUP BY dwd.user_sk, dwd.date_key;
```

### 3.3 代理键生成（MD5 哈希方式）

```sql
-- 适用于分布式数据库（如 ADB MySQL）的代理键生成
SELECT
    -- 单字段代理键
    MD5(CONCAT(CAST(user_id AS CHAR))) AS user_sk,
    -- 多字段代理键
    MD5(CONCAT(
        CAST(order_id AS CHAR),
        '|',
        CAST(item_id AS CHAR)
    )) AS order_item_sk,
    user_id,
    username,
    email
FROM ods_trade_order;
```

## 4. 经验教训

### 踩坑 #1：分区字段选择错误导致历史数据回溯困难

**场景**：订单表用 `created_at` 做分区，但 ETL 任务回溯时需要按 `updated_at` 查询，发现分区裁剪失效。
**原因**：分区字段应该是查询的高频过滤字段，而不是业务字段。
**解决**：改用 `pt` 作为分区字段（ETL 日期），业务时间放在表内。
**预防**：分区字段与业务时间字段分离。`pt` = 数据日期（ETL 视角），`business_time` = 业务时间。

### 踩坑 #2：维度表代理键类型不一致

**场景**：dim_user 的代理键是 BIGINT 自增，dim_product 的代理键是 MD5 哈希，但下游做 JOIN 时类型不匹配。
**原因**：不同表用了不同代理键生成策略。
**解决**：统一使用 BIGINT 自增（推荐）或 MD5 哈希（分布式场景）。
**预防**：在公共模型库中明确代理键生成规范，所有维度表遵循。

### 踩坑 #3：未识别"缓慢变化维"导致历史分析错误

**场景**：分析"用户等级变化对消费的影响"，但用户等级只保留了当前值，历史被覆盖。
**原因**：使用 SCD Type 1 而非 Type 2。
**解决**：重建 dim_user 表，启用 SCD Type 2，补充历史数据。
**预防**：所有"业务属性"字段默认 SCD Type 2，除非明确不需要历史。

### 踩坑 #4：OneData 与 Kimball 顺序倒置

**场景**：先建了事实表（Kimball），后做数据域划分（OneData），发现表命名、数据域归属不合理。
**原因**：没有先做 OneData 顶层规划，直接进入 Kimball 表级设计。
**解决**：重新设计表结构和命名，迁移数据。
**预防**：严格按"OneData 规划 → Kimball 设计"顺序：先有总线矩阵、指标字典，再做表设计。

### 踩坑 #5：公共维度被各业务域自定义

**场景**：交易域有自己的 dim_user，流量域也有自己的 dim_user，但定义不一致。
**原因**：未识别"用户"是公共维度，被各域重复定义。
**解决**：合并到统一的 dim_user，其他域通过 JOIN 复用。
**预防**：在 OneData 数据域划分阶段，识别公共维度，建立公共模型库。

## 5. 协作建议

### 5.1 与需求方协作

- 需求评审阶段同步建模方案，避免后期返工
- 复杂需求要求建模工程师参与需求澄清
- 上线后持续收集下游反馈，迭代优化

### 5.2 与开发团队协作

- DDL 提前评审，字段命名、类型、分区策略需团队确认
- 大表上线前做性能测试（10x 数据量压测）
- 关键模型变更走变更审批流程

### 5.3 建模师自身建议

- **从 OneData 开始**：先理解数据域、业务过程，再做表级设计
- **先粒度后指标**：粒度错了所有指标都白做
- **保持简单**：能用星型就不用雪花，能用 SCD2 就不混用其他类型
- **文档先行**：建模前先写设计文档，团队评审后再实施

---

**附录**：
- 完整方法论：[onedata-methodology.md](onedata-methodology.md)
- 详细规范：[data-modeling-standards.md](data-modeling-standards.md)
- 设计模板：[model-design.md](model-design.md)
- Schema 文档：[schema-doc.md](schema-doc.md)
