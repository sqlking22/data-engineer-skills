# 数据建模标准与规范

## 目录

1. [维度建模核心概念](#维度建模核心概念)
2. [模型设计模式](#模型设计模式)
3. [命名规范](#命名规范)
4. [表结构设计规范](#表结构设计规范)
5. [OneData 建模理论](#onedata-建模理论)
6. [数据血缘规范](#数据血缘规范)

> **重要**：OneData 方法论已独立成文，详见 [onedata-methodology.md](onedata-methodology.md)。本文档 OneData 章节为概览，完整内容（数据域划分工作流、总线矩阵模板、指标体系构建、分层落地规范、与 Kimball 协作流程）请参考独立文档。

---

## 维度建模核心概念

### 事实表 (Fact Table)

**定义**：存储业务过程的度量数据，是数据分析的核心。

**特征**：
- 包含外键关联到维度表
- 包含数值型度量（可累加、半累加、不可累加）
- 通常有非常大的数据量
- 记录数随时间增长

**类型**：
| 类型 | 说明 | 示例 |
|------|------|------|
| 事务事实表 | 记录单个业务事件 | 订单表、支付表 |
| 周期快照 | 记录某一时间点的状态 | 每日库存余额 |
| 累积快照 | 记录业务过程的多个阶段 | 订单全流程 |
| 无事实事实表 | 记录事件的发生 | 点击流、访问日志 |

**设计要点**：
```
事实表 = 维度外键 + 退化维度 + 度量 + 时间戳

示例：订单事实表
┌─────────────┬─────────────┬─────────────┬─────────────┬─────────────┐
│ date_key    │ user_key    │ product_key │ order_id    │ quantity    │
│ (FK)        │ (FK)        │ (FK)        │ (退化)      │ (度量)      │
├─────────────┼─────────────┼─────────────┼─────────────┼─────────────┤
│ 20240101    │ 10001       │ 5001        │ ORD2024001  │ 2           │
│ 20240101    │ 10002       │ 5002        │ ORD2024002  │ 1           │
└─────────────┴─────────────┴─────────────┴─────────────┴─────────────┘
```

### 维度表 (Dimension Table)

**定义**：存储业务实体的描述性属性，为事实表提供上下文。

**特征**：
- 包含主键（通常是代理键）
- 包含丰富的描述属性
- 数据量相对较小
- 相对稳定，变化缓慢

**类型**：
| 类型 | 说明 | 处理策略 |
|------|------|----------|
| 类型0 | 原始值，永不改变 | 直接插入 |
| 类型1 | 覆盖旧值 | UPDATE直接更新 |
| 类型2 | 保留历史，新增版本 | 增加生效/失效日期 |
| 类型3 | 保留有限历史 | 增加旧值字段 |
| 类型4 | 历史表 | 当前表+历史表 |
| 类型6 | 混合类型 | 组合1+2+3 |

**设计要点**：
```
维度表 = 代理键 + 自然键 + 描述属性 + 层级属性 + SCD字段

示例：用户维度表（SCD Type 2）
┌─────────┬─────────┬──────────┬─────────┬─────────────┬─────────────┐
│ user_sk │ user_id │ username │ status  │ valid_from  │ valid_to    │
│ (PK)    │ (NK)    │          │         │             │             │
├─────────┼─────────┼──────────┼─────────┼─────────────┼─────────────┤
│ 1       │ 10001   │ 张三     │ active  │ 2024-01-01  │ 9999-12-31  │
│ 2       │ 10001   │ 张三_改  │ active  │ 2024-03-01  │ 9999-12-31  │ ← 历史版本
└─────────┴─────────┴──────────┴─────────┴─────────────┴─────────────┘
```

### 星型模型 vs 雪花模型

| 特性 | 星型模型 | 雪花模型 |
|------|----------|----------|
| 结构 | 维度表直接连接事实表 | 维度表进一步规范化 |
| 查询复杂度 | 简单，JOIN少 | 复杂，JOIN多 |
| 存储空间 | 略多（有冗余） | 较少（规范化） |
| 查询性能 | 快 | 较慢 |
| 维护难度 | 简单 | 复杂 |
| 推荐场景 | 大多数分析场景 | 维度属性极多的场景 |

**推荐**：默认使用星型模型，除非维度属性非常多且需要严格规范化。

---

## 模型设计模式

### 1. 星型模型设计

```
                    ┌─────────────┐
                    │   dim_date  │
                    │   (日期维度) │
                    └──────┬──────┘
                           │
    ┌─────────────┐       │       ┌─────────────┐
    │  dim_user   │       │       │ dim_product │
    │  (用户维度)  │       │       │  (商品维度)  │
    └──────┬──────┘       │       └──────┬──────┘
           │              │              │
           └──────────────┼──────────────┘
                          │
                    ┌─────┴─────┐
                    │fact_orders│
                    │ (订单事实) │
                    └───────────┘
```

### 2. 一致性维度

多个事实表共享相同的维度表，确保跨业务流程分析的一致性。

```
    dim_date ◄────────┬────────► fact_sales
                      │
    dim_product ◄─────┼────────► fact_inventory
                      │
    dim_store ◄───────┴────────► fact_returns
```

### 3. 桥接表（多对多关系）

处理事实表与维度表的多对多关系。

```
    dim_order ◄─────┐
                    │
               ┌────┴────┐
               │bridge_  │     权重：表示分摊比例
               │order_   │     或：表示角色（主/次）
               │product  │
               └────┬────┘
                    │
    dim_product ◄───┘
```

### 4. 微型维度

将大型维度表中变化频繁的属性分离出来。

```
    ┌─────────────────────────────────────┐
    │           dim_user                  │
    │  (稳定属性：用户ID、注册时间等)      │
    └───────────────┬─────────────────────┘
                    │ FK: user_attr_key
                    ▼
    ┌─────────────────────────────────────┐
    │      dim_user_attributes            │
    │  (变化属性：等级、积分、标签等)      │
    │  Type 2 SCD                         │
    └─────────────────────────────────────┘
```

### 5. 事实表分区策略

| 分区方式 | 适用场景 | 优点 |
|----------|----------|------|
| 时间分区 | 按天/月分区 | 高效删除旧数据，并行查询 |
| 范围分区 | 按日期范围 | 适合时间序列分析 |
| 列表分区 | 按地区/类别 | 适合区域分析 |
| 哈希分区 | 均匀分布 | 适合数据倾斜严重的场景 |

---

## 命名规范

### 表命名

| 类型 | 前缀 | 示例 |
|------|------|------|
| 事实表 | `fct_` | `fct_orders`, `fct_page_views` |
| 维度表 | `dim_` | `dim_user`, `dim_product` |
| 桥接表 | `bridge_` | `bridge_order_product` |
| 汇总表 | `agg_` | `agg_daily_sales` |
| 临时表 | `tmp_` | `tmp_order_processing` |
| 视图 | `vw_` | `vw_order_detail` |

### 字段命名

| 类型 | 后缀/前缀 | 示例 |
|------|----------|------|
| 代理键 | `_sk` | `user_sk`, `order_sk` |
| 自然键 | `_nk` | `user_nk` 或直接 `user_id` |
| 外键 | `_fk` 或原字段名 | `user_fk` 或 `user_id` |
| 度量 | 无 | `quantity`, `amount` |
| 计数 | `_cnt` | `order_cnt` |
| 标记 | `_flg` / `_is_` | `is_active`, `deleted_flg` |
| 时间戳 | `_at` | `created_at`, `updated_at` |
| 日期 | `_date` | `order_date`, `birth_date` |

### 数据仓库分层命名

遵循阿里 OneData 建模体系的分层规范：

| 层 | 前缀 | 说明 | 示例 |
|----|------|------|------|
| ODS（贴源层） | `ods_` | 原始数据，保持源系统结构 | `ods_order_info` |
| DWD（明细层） | `dwd_` | 数据清洗、标准化、维度关联 | `dwd_order_detail` |
| DWS（汇总层） | `dws_` | 轻度汇总，面向分析主题 | `dws_trade_user_1d` |
| ADS（应用层） | `ads_` | 面向报表/应用的结果表 | `ads_sales_report` |
| DIM（维度层） | `dim_` | 公共维度表，贯穿各层 | `dim_user`, `dim_product` |

---

## 表结构设计规范

### 事实表结构模板（AnalyticDB MySQL 合法 DDL）

> ⚠️ 以下语法以阿里云 AnalyticDB MySQL 为准。ADB 关键约束：① 主键必须包含分布键和分区键；② 不支持唯一索引（`UNIQUE KEY`）、不支持多列复合索引；③ 不支持独立 `CREATE INDEX`，索引用 `INDEX` 内联；④ 不支持 `PARTITION BY RANGE ... VALUES LESS THAN`，只能 `PARTITION BY VALUE(...)`；⑤ 列属性不支持 `ON UPDATE CURRENT_TIMESTAMP`；⑥ `AUTO_INCREMENT` 仅限 BIGINT，值唯一但非顺序递增。详见 [ADB CREATE TABLE 官方文档](https://help.aliyun.com/zh/analyticdb/analyticdb-for-mysql/developer-reference/create-table)。

```sql
CREATE TABLE dwd_trade_order_detail (
    -- 代理键（ADB 自增列仅限 BIGINT，值唯一但非顺序、不从1开始）
    order_sk BIGINT NOT NULL AUTO_INCREMENT,

    -- 退化维度（作为分布键，高基数）
    order_id VARCHAR(32) NOT NULL COMMENT '订单编号（退化维度）',

    -- 维度外键
    date_key INT NOT NULL COMMENT '日期维度外键',
    user_sk BIGINT NOT NULL COMMENT '用户维度代理键',
    product_sk BIGINT NOT NULL COMMENT '商品维度代理键',

    -- 分区键（必须包含在主键中）
    dt DATE NOT NULL COMMENT '业务日期（分区键）',

    -- 度量
    quantity INT NOT NULL COMMENT '数量',
    unit_price DECIMAL(10,2) NOT NULL COMMENT '单价',
    discount_amount DECIMAL(10,2) DEFAULT 0 COMMENT '优惠金额',
    total_amount DECIMAL(10,2) NOT NULL COMMENT '订单金额',

    -- 审计字段（ADB 列属性仅支持 DEFAULT，不支持 ON UPDATE）
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    etl_batch_id VARCHAR(32) COMMENT 'ETL批次号',

    -- 主键：必须包含分布键(order_id)和分区键(dt)，二者置于主键前部
    PRIMARY KEY (order_id, dt),

    -- 外键（内核 3.1.10+，仅用于 JOIN 消除，不做完整性校验；不支持复合外键）
    FOREIGN KEY (user_sk) REFERENCES dim_user(user_sk),
    FOREIGN KEY (product_sk) REFERENCES dim_product(product_sk)
)
DISTRIBUTED BY HASH(order_id)                          -- 分布键选高基数、常用 JOIN 字段
PARTITION BY VALUE(DATE_FORMAT(dt, '%Y%m')) LIFECYCLE 36  -- 按月分区，保留 36 个分区
COMMENT '订单明细事实表';
-- 说明：ADB 默认为全表所有列自动创建索引，无需手动 CREATE INDEX。
```

### 维度表结构模板（SCD Type 2）

```sql
CREATE TABLE dim_user (
    -- 代理键（分布键 + 主键）
    user_sk BIGINT NOT NULL AUTO_INCREMENT,

    -- 自然键
    user_id BIGINT NOT NULL COMMENT '用户自然键',

    -- 描述属性
    username VARCHAR(50) NOT NULL COMMENT '用户名',
    email VARCHAR(100) COMMENT '邮箱',
    phone VARCHAR(20) COMMENT '手机号',
    gender VARCHAR(10) COMMENT '性别',
    birth_date DATE COMMENT '生日',
    register_date DATE NOT NULL COMMENT '注册日期',

    -- 层级属性
    city_code VARCHAR(10) COMMENT '城市代码',
    city_name VARCHAR(50) COMMENT '城市名称',
    province_code VARCHAR(10) COMMENT '省份代码',
    province_name VARCHAR(50) COMMENT '省份名称',

    -- SCD Type 2 字段（is_current 用 VARCHAR(1) Y/N 代替 BOOLEAN，兼容性更好）
    valid_from DATETIME NOT NULL COMMENT '生效时间',
    valid_to DATETIME NOT NULL COMMENT '失效时间',
    is_current VARCHAR(1) DEFAULT 'Y' COMMENT '是否当前版本(Y/N)',

    -- 审计字段
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- 主键：ADB 主键即唯一约束（ADB 不支持 UNIQUE KEY，故用主键保证唯一）。
    -- 维度表通常不分区，按代理键分布即可。
    -- (user_id, valid_from) 的业务唯一性由 ETL 流程保证。
    PRIMARY KEY (user_sk)
)
DISTRIBUTED BY HASH(user_sk)
COMMENT '用户维度表（SCD Type 2）';
-- 说明：若需按 user_id 高频查询，可内联 INDEX(user_id) 单列索引（ADB 不支持复合索引）。
```

---

## OneData 建模理论

OneData 是阿里提出的数据建设方法论，核心目标是将数据"标准化、体系化、服务化"，与本套件的 Kimball 维度建模思想相辅相成。

### 核心概念

| 概念 | 说明 | 示例 |
|------|------|------|
| **数据域** | 面向业务分析，将业务过程进行抽象归类 | 交易域、用户域、商品域、流量域 |
| **业务过程** | 业务活动中的具体事件 | 下单、支付、退款 |
| **原子指标** | 基于某一业务过程的度量值 | `SUM(支付金额)` |
| **派生指标** | 原子指标 + 时间周期 + 修饰词 | 最近7天_广东省_支付金额 |
| **修饰词** | 对指标的限定条件 | 区域、终端、渠道 |
| **时间周期** | 统计的时间范围 | 最近1天、最近7天、最近30天 |
| **维度** | 分析观察的角度 | 日期、地区、用户等级 |

### 与 Kimball 维度建模的关系

| 维度 | Kimball 维度建模 | OneData 建模理论 |
|------|-----------------|-----------------|
| **核心关注** | 事实表 + 维度表的星型模型设计 | 指标体系的标准化与规范化 |
| **输出物** | 数据模型（表结构） | 指标体系 + 数据模型 |
| **设计起点** | 业务过程 → 粒度声明 → 维度设计 | 数据域划分 → 业务过程识别 → 指标定义 |
| **互补关系** | 提供表级设计方法 | 提供指标管理方法 |

> **实践建议**：用 OneData 方法划分数据域、定义指标体系，用 Kimball 方法设计具体的事实表和维度表。两者结合使用。

### 数据域划分

数据域是 OneData 建模的第一步，将业务过程按主题归类：

```
示例：电商业务的数据域划分

┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│  交易域  │  │  用户域  │  │  商品域  │  │  流量域  │
├──────────┤  ├──────────┤  ├──────────┤  ├──────────┤
│ 下单     │  │ 注册     │  │ 上架     │  │ 浏览     │
│ 支付     │  │ 登录     │  │ 搜索     │  │ 点击     │
│ 退款     │  │ 等级变更 │  │ 收藏     │  │ 曝光     │
│ 发货     │  │ 注销     │  │ 评价     │  │ 加购     │
└──────────┘  └──────────┘  └──────────┘  └──────────┘
```

### 总线矩阵

总线矩阵是 OneData 的核心设计工具，描述业务过程与维度的关系：

| 业务过程 | 日期 | 用户 | 商品 | 地区 | 渠道 | 店铺 |
|---------|------|------|------|------|------|------|
| 下单 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 支付 | ✓ | ✓ | - | ✓ | ✓ | - |
| 退款 | ✓ | ✓ | ✓ | - | - | ✓ |
| 登录 | ✓ | ✓ | - | ✓ | ✓ | - |
| 浏览 | ✓ | ✓ | ✓ | - | ✓ | - |

### 数据仓库分层规范

遵循 OneData 的层次划分：

```
ODS（贴源层）
  ↓  数据清洗、去重、标准化
DWD（明细层）  ← DIM（维度层，贯穿各层）
  ↓  轻度汇总、指标计算
DWS（汇总层）
  ↓  面向应用聚合、报表加工
ADS（应用层）
```

| 层级 | 全称 | 职责 | 数据特征 |
|------|------|------|---------|
| **ODS** | Operational Data Store | 贴源层，保持源系统结构 | 原始数据，不做转换 |
| **DWD** | Data Warehouse Detail | 明细层，数据清洗和标准化 | 明细粒度，关联维度代理键 |
| **DWS** | Data Warehouse Summary | 汇总层，面向分析主题 | 轻度汇总，按天/周/月聚合 |
| **ADS** | Application Data Service | 应用层，面向报表/产品 | 高度聚合，可直接消费 |
| **DIM** | Dimension | 维度层，公共维度表 | 贯穿各层，保证一致性 |

### OneData 指标规范

指标命名遵循 OneData 规范：

```
格式：{原子指标}_{时间周期}_{修饰词}

示例：
- 最近7天_广东省_支付金额
- 最近30天_iOS_新注册用户数
- 当日_全平台_下单笔数
```

对应的表字段命名：
```sql
-- DWS 层指标字段
CREATE TABLE dws_trade_user_1d (
    user_id       BIGINT  COMMENT '用户ID',
    pay_amount_1d DECIMAL(18,2) COMMENT '最近1天支付金额',
    pay_cnt_1d    BIGINT  COMMENT '最近1天支付次数',
    pay_amount_7d DECIMAL(18,2) COMMENT '最近7天支付金额',
    pay_cnt_30d   BIGINT  COMMENT '最近30天支付次数'
) COMMENT '用户交易1日汇总表';
```

---

## 数据血缘规范

### 血缘关系类型

| 类型 | 说明 | 示例 |
|------|------|------|
| 表级血缘 | 表与表之间的依赖 | `stg_orders` → `fct_orders` |
| 字段级血缘 | 字段与字段的映射 | `stg_orders.user_id` → `fct_orders.user_sk` |
| 任务级血缘 | ETL任务间的依赖 | `load_staging` → `load_marts` |

### 血缘标注规范

在SQL中使用注释标注血缘关系：

```sql
/*
 * 上游依赖（ODS 贴源层）:
 *   - ods_orders
 *   - ods_order_items
 *
 * 下游消费（DWS/ADS）:
 *   - dws_trade_order_1d
 *   - ads_daily_sales
 *
 * 业务 owner: sales-team@company.com
 * 技术 owner: data-team@company.com
 */

WITH orders AS (
    -- 上游：贴源层 ods_orders（ODS）
    SELECT * FROM ods_orders
),

items AS (
    -- 上游：贴源层 ods_order_items（ODS）
    SELECT * FROM ods_order_items
)

SELECT
    -- pk: order_id from orders.order_id
    order_id,

    -- fk: user_id from orders.user_id
    user_id,

    -- measure: sum of items.amount
    SUM(i.amount) AS total_amount

FROM orders o
JOIN items i ON o.order_id = i.order_id
GROUP BY 1, 2
```

### 血缘文档格式

```yaml
# lineage.yml
table: fct_orders
lineage:
  upstream:
    tables:
      - name: raw.orders
        type: source
        mapping:
          order_id: order_id
          user_id: user_id
          amount: total_amount

      - name: raw.order_items
        type: source
        mapping:
          order_id: order_id
          product_id: product_id
          quantity: quantity

      - name: dim_users
        type: dimension
        join_key: user_id

  downstream:
    tables:
      - name: agg_daily_sales
        type: aggregate

      - name: rpt_sales_dashboard
        type: report
```

---

## 参考资料

- 《数据仓库工具箱》Ralph Kimball — 维度建模权威指南
- 阿里云 OneData 数据中台建设方法论
- 阿里云 DataWorks 官方文档: https://help.aliyun.com/product/72772.html
- 阿里云 AnalyticDB MySQL 官方文档: https://help.aliyun.com/product/190244.html
- 阿里云 MaxCompute 官方文档: https://help.aliyun.com/product/27748.html
