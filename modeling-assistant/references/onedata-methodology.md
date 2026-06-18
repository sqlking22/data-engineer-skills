---
name: onedata-methodology
description: |
  OneData 建模理论参考文档 - 阿里数据中台建设方法论。
  包含数据域划分、总线矩阵设计、指标体系构建、分层落地规范。
  与 Kimball 维度建模形成"自顶向下规划 + 自底向上设计"的协作闭环。
  触发词：OneData、数据域划分、总线矩阵、指标体系、原子指标、派生指标、数据分层。
---

# OneData 建模理论参考

阿里 OneData 方法论是数据中台建设的核心方法论，与 Kimball 维度建模形成互补：
- **OneData**：自顶向下规划，解决"建什么"——数据域划分、指标体系、总线矩阵
- **Kimball**：自底向上设计，解决"怎么建"——事实表/维度表结构、SCD策略

```
┌──────────────────────────────────────────────────────────────┐
│                    完整建模闭环                                 │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  业务需求                                                     │
│     │                                                        │
│     ▼                                                        │
│  ┌─────────────────┐      ┌─────────────────┐                │
│  │   OneData        │ ───► │   Kimball        │                │
│  │  (自顶向下)      │      │  (自底向上)      │                │
│  │                 │      │                 │                │
│  │ ① 数据域划分    │      │ ④ 事实表设计    │                │
│  │ ② 业务过程识别  │ ───► │ ⑤ 维度表设计    │                │
│  │ ③ 指标体系定义  │      │ ⑥ SCD策略选择   │                │
│  └─────────────────┘      └─────────────────┘                │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 1. 核心概念

### 1.1 基础术语表

| 概念 | 定义 | 示例 |
|------|------|------|
| **数据域** | 面向业务分析，将业务过程按主题归类 | 交易域、用户域、商品域、流量域 |
| **业务过程** | 业务活动中的具体事件 | 下单、支付、退款、注册、登录 |
| **原子指标** | 基于某一业务过程的度量值，**不可再分** | `支付金额`（= SUM(支付表.金额)） |
| **修饰词** | 对指标的限定条件（除业务过程和时间周期外） | 区域、终端、渠道、用户类型 |
| **时间周期** | 统计的时间范围 | 最近1天、最近7天、最近30天 |
| **派生指标** | 原子指标 + 修饰词 + 时间周期 | `最近7天_广东省_支付金额` |
| **衍生指标** | 多个派生指标通过四则运算得到 | `客单价 = 支付金额 / 支付订单数` |
| **维度** | 分析观察的角度，与业务过程正交 | 日期、地区、用户等级 |
| **总线矩阵** | 业务过程 × 维度的交叉关系表 | 描述"谁需要哪些维度" |

### 1.2 三种指标的关系

```
                    ┌─────────────────┐
                    │   衍生指标       │
                    │ (四则运算组合)   │
                    └────────┬────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
                ▼                         ▼
        ┌──────────────┐          ┌──────────────┐
        │  派生指标1    │          │  派生指标2    │
        │ (原子+修饰+时间)│         │ (原子+修饰+时间)│
        └──────┬───────┘          └──────┬───────┘
               │                         │
               └────────────┬────────────┘
                            │
                            ▼
                    ┌──────────────┐
                    │   原子指标    │
                    │ (业务过程度量)│
                    └──────────────┘
```

**示例**：
- 原子指标：`支付金额`
- 派生指标：`最近7天_广东省_支付金额`
- 衍生指标：`最近7天_广东省_客单价 = 支付金额 / 支付订单数`

---

## 2. 数据域划分工作流

### 2.1 划分原则

| 原则 | 说明 |
|------|------|
| **业务驱动** | 围绕业务经营活动划分，而非按系统模块 |
| **正交性** | 各数据域之间不重叠、无交叉 |
| **稳定性** | 域边界一旦确定，轻易不调整 |
| **覆盖性** | 所有业务过程必须归属于某个数据域 |
| **MECE 原则** | 相互独立、完全穷尽（Mutually Exclusive, Collectively Exhaustive） |

### 2.2 划分步骤

#### Step 1：业务调研

收集以下信息：
- 公司的核心业务线（电商、金融、物流、内容……）
- 主营业务流程（从用户注册到交易完成）
- 业务部门划分（销售部、市场部、运营部……）
- 现有的数据报表和分析主题

#### Step 2：业务过程梳理

列出所有业务过程（动词短语），按发生频率分组：

```yaml
# 业务过程清单
business_processes:
  - name: "注册"
    domain: "用户域"
    description: "用户在系统创建账号"
    source_system: ["user-service", "auth-service"]
    
  - name: "登录"
    domain: "用户域"
    description: "用户通过凭证访问系统"
    source_system: ["user-service"]
    
  - name: "下单"
    domain: "交易域"
    description: "用户创建订单"
    source_system: ["order-service"]
    
  - name: "支付"
    domain: "交易域"
    description: "用户完成订单支付"
    source_system: ["payment-service"]
    
  - name: "退款"
    domain: "交易域"
    description: "用户申请订单退款"
    source_system: ["refund-service"]
    
  - name: "浏览"
    domain: "流量域"
    description: "用户浏览商品页面"
    source_system: ["tracking-service"]
    
  - name: "加购"
    domain: "流量域"
    description: "用户将商品加入购物车"
    source_system: ["cart-service"]
```

#### Step 3：数据域归类

将业务过程按主题归类：

```yaml
# 数据域划分结果
data_domains:
  - name: "用户域"
    code: "user"
    description: "用户生命周期相关"
    business_processes: ["注册", "登录", "注销", "等级变更"]
    priority: "P0"
    
  - name: "交易域"
    code: "trade"
    description: "订单交易全流程"
    business_processes: ["下单", "支付", "退款", "发货", "收货"]
    priority: "P0"
    
  - name: "商品域"
    code: "product"
    description: "商品信息及变更"
    business_processes: ["上架", "下架", "改价", "评价"]
    priority: "P0"
    
  - name: "流量域"
    code: "traffic"
    description: "用户行为埋点"
    business_processes: ["浏览", "点击", "加购", "搜索", "曝光"]
    priority: "P1"
    
  - name: "营销域"
    code: "marketing"
    description: "营销活动与转化"
    business_processes: ["领券", "用券", "活动报名", "线索跟进"]
    priority: "P1"
    
  - name: "风控域"
    code: "risk"
    description: "风险识别与控制"
    business_processes: ["欺诈识别", "信用评估", "限额控制"]
    priority: "P2"
```

#### Step 4：评审与确认

- 与业务方对齐：业务过程归属是否合理
- 与技术方对齐：数据源是否可获取
- 与数据治理对齐：是否需要新增数据域
- 评审通过后输出 **数据域划分表** 作为建模基线

---

## 3. 总线矩阵设计

### 3.1 总线矩阵的作用

总线矩阵（Bus Matrix）是 OneData 的核心设计工具，描述**业务过程 × 维度**的交叉关系，是后续维度建模和指标定义的依据。

### 3.2 总线矩阵模板

```yaml
# bus_matrix.yaml
metadata:
  version: "1.0"
  project: "电商数据仓库"
  generated_at: "2024-01-15"
  generated_by: "onedata-methodology"
  
matrix:
  # 行为业务过程，列为维度
  # ✓ 表示该业务过程需要该维度
  
  dimensions:
    - code: "date"      # 日期
      type: "公共维度"
      owner: "数据平台"
    - code: "user"      # 用户
      type: "公共维度"
      owner: "用户域"
    - code: "product"   # 商品
      type: "公共维度"
      owner: "商品域"
    - code: "region"    # 地区
      type: "公共维度"
      owner: "数据平台"
    - code: "channel"   # 渠道
      type: "公共维度"
      owner: "流量域"
    - code: "store"     # 店铺
      type: "公共维度"
      owner: "交易域"
      
  business_processes:
    - name: "下单"
      domain: "交易域"
      dimensions: ["date", "user", "product", "region", "channel", "store"]
      
    - name: "支付"
      domain: "交易域"
      dimensions: ["date", "user", "-", "region", "channel", "-"]
      
    - name: "退款"
      domain: "交易域"
      dimensions: ["date", "user", "product", "-", "-", "store"]
      
    - name: "注册"
      domain: "用户域"
      dimensions: ["date", "user", "-", "region", "channel", "-"]
      
    - name: "登录"
      domain: "用户域"
      dimensions: ["date", "user", "-", "region", "channel", "-"]
      
    - name: "浏览"
      domain: "流量域"
      dimensions: ["date", "user", "product", "-", "channel", "-"]
      
    - name: "加购"
      domain: "流量域"
      dimensions: ["date", "user", "product", "-", "channel", "-"]
```

### 3.3 总线矩阵可视化

```
                  日期  用户  商品  地区  渠道  店铺
业务过程\维度      ────  ────  ────  ────  ────  ────
下单              ✓     ✓     ✓     ✓     ✓     ✓
支付              ✓     ✓     -     ✓     ✓     -
退款              ✓     ✓     ✓     -     -     ✓
注册              ✓     ✓     -     ✓     ✓     -
登录              ✓     ✓     -     ✓     ✓     -
浏览              ✓     ✓     ✓     -     ✓     -
加购              ✓     ✓     ✓     -     ✓     -
```

### 3.4 总线矩阵设计规则

| 规则 | 说明 | 违反后果 |
|------|------|----------|
| **一致性维度** | 同一维度（如用户）在所有业务过程中保持一致定义 | 跨业务分析数据冲突 |
| **核心维度必备** | date 维度必须存在于所有业务过程 | 无法做时间序列分析 |
| **业务相关性** | 只为真正有分析需求的业务过程添加维度 | 维度爆炸 |
| **去重原则** | 多个相似维度应合并（如渠道和入口） | 维度冗余 |
| **粒度一致** | 同一维度的粒度必须统一 | 关联查询结果错误 |

### 3.5 总线矩阵 → 维度表设计

总线矩阵中的每个"✓"对应一张维度表与事实表的关联：

```
总线矩阵单元格                维度建模
─────────────────────────────────────────
下单 × user      ──►  fct_orders.user_sk → dim_user
下单 × product   ──►  fct_orders.product_sk → dim_product
支付 × channel   ──►  fct_pay.channel_key → dim_channel
...
```

**规则**：所有业务过程共享同一份 `dim_*` 表（一致性维度），不在不同业务过程中重复定义。

---

## 4. 指标体系构建

### 4.1 指标分层体系

```
指标体系
├── 原子指标（不可再分）
│   ├── 支付金额 = SUM(支付表.支付金额)
│   ├── 订单数 = COUNT(订单ID)
│   └── 用户数 = COUNT(DISTINCT 用户ID)
│
├── 派生指标（原子 + 修饰 + 时间）
│   ├── 最近7天_广东省_支付金额
│   ├── 最近30天_全平台_新注册用户数
│   └── 当日_全平台_订单数
│
└── 衍生指标（派生指标四则运算）
    ├── 客单价 = 支付金额 / 订单数
    ├── 转化率 = 支付订单数 / 浏览次数
    └── 复购率 = 复购用户数 / 总用户数
```

### 4.2 原子指标定义模板

```yaml
# atomic_metrics.yaml
version: "1.0"
metadata:
  owner_domain: "交易域"
  generated_at: "2024-01-15"
  
atomic_metrics:
  - code: "AT_001"
    name: "支付金额"
    english_name: "pay_amount"
    description: "用户完成支付的总金额，单位元"
    
    business_process: "支付"  # 所属业务过程
    domain: "交易域"
    
    measure:  # 度量定义
      aggregation: "SUM"
      source_field: "payment.pay_amount"
      data_type: "DECIMAL(18,2)"
      
    constraints:
      filter: "status = 'paid'"   # 必须的过滤条件
      not_null: true
      positive: true
      
    owner: "payment-team"
    
  - code: "AT_002"
    name: "订单数"
    english_name: "order_count"
    description: "订单总数"
    
    business_process: "下单"
    domain: "交易域"
    
    measure:
      aggregation: "COUNT"
      source_field: "order.order_id"
      data_type: "BIGINT"
      
    constraints:
      filter: "status != 'cancelled'"
      not_null: true
      
    owner: "order-team"
```

### 4.3 派生指标定义模板

```yaml
# derived_metrics.yaml
version: "1.0"

derived_metrics:
  - code: "DR_001"
    name: "最近7天广东省支付金额"
    english_name: "pay_amount_7d_gd"
    description: "最近7天（含今天）广东省所有支付订单的总金额"
    
    # 引用原子指标
    atomic_metric: "AT_001"     # 支付金额
    atomic_metric_name: "pay_amount"
    
    # 修饰词
    modifiers:
      - name: "地区"
        value: "广东省"
        type: "枚举值"
      - name: "时间周期"
        value: "最近7天"
        type: "相对时间"
        
    # 派生规则
    derivation:
      time_window: "7d"
      partition_field: "pay_date"
      filter: "province = '广东省'"
      
    data_type: "DECIMAL(18,2)"
    
  - code: "DR_002"
    name: "最近30天iOS端新注册用户数"
    english_name: "new_user_count_30d_ios"
    description: "最近30天内通过iOS设备注册的新用户数"
    
    atomic_metric: "AT_003"     # 新注册用户数
    atomic_metric_name: "new_user_count"
    
    modifiers:
      - name: "终端"
        value: "iOS"
        type: "枚举值"
      - name: "时间周期"
        value: "最近30天"
        type: "相对时间"
        
    derivation:
      time_window: "30d"
      partition_field: "register_date"
      filter: "platform = 'iOS' AND is_new = TRUE"
```

### 4.4 衍生指标定义模板

```yaml
# composite_metrics.yaml
version: "1.0"

composite_metrics:
  - code: "CO_001"
    name: "客单价"
    english_name: "arpu"
    description: "每个订单的平均支付金额"
    
    formula: "AT_001 / AT_002"   # 支付金额 / 订单数
    
    components:
      - metric: "AT_001"
        name: "支付金额"
      - metric: "AT_002"
        name: "订单数"
        
    unit: "元/单"
    precision: 2
    
    # 衍生指标也可以加修饰词
    modifiers:
      - name: "时间周期"
        value: "最近7天"
        
  - code: "CO_002"
    name: "支付转化率"
    english_name: "pay_conversion_rate"
    description: "完成支付的订单占总下单订单的比例"
    
    formula: "支付订单数 / 下单订单数"
    
    components:
      - metric: "支付订单数"
        type: "派生指标"
        ref: "DR_003"
      - metric: "下单订单数"
        type: "派生指标"
        ref: "DR_004"
        
    unit: "%"
    precision: 2
```

### 4.5 指标命名规范

```
派生指标命名格式：{原子指标}_{时间周期}_{修饰词}

示例：
- 最近1天_全平台_支付金额         → pay_amount_1d_all
- 最近7天_广东省_支付金额         → pay_amount_7d_gd
- 最近30天_iOS_新注册用户数       → new_user_count_30d_ios
- 当月_广东省_订单数              → order_count_cm_gd

其中：
- 时间周期：1d / 7d / 30d / cm（当月）/ pm（上一月）/ ytd（年初至今）
- 修饰词：枚举值或维度编码
- 原子指标：原子指标的英文名
```

### 4.6 指标字典输出

| 指标编码 | 指标名称 | 类型 | 业务过程 | 数据域 | 度量 | 修饰词 | 时间周期 | 负责人 |
|----------|---------|------|----------|--------|------|--------|----------|--------|
| AT_001 | 支付金额 | 原子 | 支付 | 交易 | SUM(pay_amount) | - | - | payment-team |
| AT_002 | 订单数 | 原子 | 下单 | 交易 | COUNT(order_id) | - | - | order-team |
| DR_001 | 最近7天广东支付金额 | 派生 | 支付 | 交易 | - | 广东省 | 最近7天 | data-team |
| DR_002 | 最近30天iOS新注册用户 | 派生 | 注册 | 用户 | - | iOS | 最近30天 | data-team |
| CO_001 | 客单价 | 衍生 | - | 交易 | AT_001 / AT_002 | - | - | data-team |
| CO_002 | 支付转化率 | 衍生 | - | 交易 | 支付订单 / 下单订单 | - | - | data-team |

---

## 5. 数据仓库分层落地规范

### 5.1 分层架构

```
┌──────────────────────────────────────────────────────────┐
│                       ADS 应用层                          │
│  职责：面向报表/产品的最终结果，跨域聚合，高度汇总          │
│  命名：ads_{业务主题}_{报表名}                            │
│  示例：ads_sales_daily_report, ads_user_retention_30d     │
├──────────────────────────────────────────────────────────┤
│                       DWS 汇总层                          │
│  职责：按主题轻度汇总，宽表形态，公共指标沉淀              │
│  命名：dws_{数据域}_{汇总主题}_{时间粒度}                  │
│  示例：dws_trade_user_1d, dws_user_login_1d              │
├──────────────────────────────────────────────────────────┤
│                       DWD 明细层                          │
│  职责：清洗+标准化+维度关联，业务过程级明细                │
│  命名：dwd_{数据域}/{业务过程}/{dwd_表名}                 │
│  示例：dwd_trade/dwd_trade_order_detail                  │
├──────────────────────────────────────────────────────────┤
│                       ODS 贴源层                          │
│  职责：原样保留源系统数据，不做转换                        │
│  命名：ods_{数据源}_{表名}                                │
│  示例：ods_mysql_orders, ods_kafka_payment_log            │
├──────────────────────────────────────────────────────────┤
│                  DIM 维度层（贯穿各层）                    │
│  职责：一致性维度表，全局共享                              │
│  命名：dim_{维度主题}                                     │
│  示例：dim_user, dim_product, dim_date                   │
└──────────────────────────────────────────────────────────┘
```

### 5.2 各层表设计规范

#### ODS 层规范

```yaml
# ODS 层设计原则
design_principles:
  - "原样保留源系统字段，不做清洗"
  - "增量分区：按数据日期分区（pt = 'YYYYMMDD'）"
  - "附加 ETL 元数据：etl_time, etl_batch_id, source_system"
  - "数据保留：保留 7~30 天，支持回溯重跑"
  - "每个源表对应一张 ODS 表"

table_template: |
  CREATE TABLE ods_{source_system}_{table_name} (
    -- 源系统原始字段
    ...
    
    -- ETL 元数据字段（固定）
    etl_time TIMESTAMP COMMENT 'ETL 处理时间',
    etl_batch_id STRING COMMENT 'ETL 批次号',
    etl_source STRING COMMENT '源系统标识',
    pt STRING COMMENT '分区字段 YYYYMMDD'
  )
  PARTITIONED BY (pt STRING)
  STORED AS ORC;
```

#### DWD 层规范

```yaml
# DWD 层设计原则
design_principles:
  - "一个业务过程一张表（粒度统一）"
  - "清洗：去重、过滤空值、统一格式"
  - "标准化：日期/枚举值统一编码"
  - "维度退化：高频维度属性直接冗余到事实表"
  - "分区：按业务时间分区（pt = 'YYYYMMDD'）"
  - "数据保留：保留 1~3 年"

table_template: |
  CREATE TABLE dwd_{domain}_{business_process}_{grain} (
    -- 维度外键
    user_sk BIGINT COMMENT '用户代理键',
    product_sk BIGINT COMMENT '商品代理键',
    date_key INT COMMENT '日期代理键',
    
    -- 退化维度
    order_id STRING COMMENT '订单号（退化维度）',
    
    -- 度量
    quantity INT COMMENT '数量',
    pay_amount DECIMAL(18,2) COMMENT '支付金额',
    
    -- 业务时间
    business_time TIMESTAMP COMMENT '业务发生时间',
    
    -- ETL 元数据
    etl_time TIMESTAMP,
    etl_batch_id STRING,
    pt STRING
  )
  PARTITIONED BY (pt STRING)
  STORED AS ORC;
```

#### DWS 层规范

```yaml
# DWS 层设计原则
design_principles:
  - "按数据域 + 主题汇总，宽表形态"
  - "时间粒度：1d / 7d / 30d / 1m 等"
  - "维度列：保留所有常用维度（dim_user.*, dim_product.*）"
  - "指标列：原子指标的派生结果（已应用修饰词和时间周期）"
  - "分区：按汇总日期分区"
  - "数据保留：保留 3~5 年（视业务需求）"

table_template: |
  CREATE TABLE dws_{domain}_{summary_topic}_{time_grain} (
    -- 主键维度
    user_sk BIGINT,
    product_sk BIGINT,
    date_key INT,
    
    -- 派生指标列
    pay_amount_1d DECIMAL(18,2) COMMENT '最近1天支付金额',
    pay_count_1d BIGINT COMMENT '最近1天支付次数',
    pay_amount_7d DECIMAL(18,2) COMMENT '最近7天支付金额',
    pay_count_7d BIGINT COMMENT '最近7天支付次数',
    pay_amount_30d DECIMAL(18,2) COMMENT '最近30天支付金额',
    pay_count_30d BIGINT COMMENT '最近30天支付次数',
    
    -- 衍生指标列
    avg_pay_amount_30d DECIMAL(18,2) COMMENT '最近30天客单价',
    
    -- ETL 元数据
    etl_time TIMESTAMP,
    pt STRING
  )
  PARTITIONED BY (pt STRING);
```

#### ADS 层规范

```yaml
# ADS 层设计原则
design_principles:
  - "面向具体报表/产品/接口，高度定制化"
  - "跨数据域聚合（如交易 + 用户 + 商品）"
  - "时间粒度：报表所需粒度（日/周/月）"
  - "维度列：报表所需维度"
  - "指标列：报表展示指标"
  - "数据保留：按报表归档要求"

table_template: |
  CREATE TABLE ads_{report_name} (
    -- 报表展示字段
    report_date DATE,
    region_name VARCHAR(50),
    product_category VARCHAR(50),
    
    -- 报表展示指标
    gmv DECIMAL(18,2) COMMENT 'GMV',
    order_count BIGINT COMMENT '订单数',
    user_count BIGINT COMMENT '用户数',
    arpu DECIMAL(18,2) COMMENT '客单价',
    
    -- 排名/分组
    rank_in_region INT COMMENT '区域内排名',
    
    -- ETL 元数据
    etl_time TIMESTAMP,
    pt STRING
  )
  PARTITIONED BY (pt STRING);
```

#### DIM 层规范

```yaml
# DIM 层设计原则
design_principles:
  - "一致性维度：所有业务过程共享同一份维度表"
  - "SCD 策略：默认 SCD Type 2，保留历史"
  - "代理键：使用 BIGINT 自增或哈希生成"
  - "自然键：保留业务系统的原始 ID"
  - "描述属性：丰富的属性列，支持多角度分析"
  - "层级属性：地域层级、组织层级等"

table_template: |
  CREATE TABLE dim_{dimension_name} (
    -- 代理键（主键）
    {dim}_sk BIGINT PRIMARY KEY,
    
    -- 自然键
    {dim}_id VARCHAR(64) NOT NULL,
    
    -- 描述属性
    ...
    
    -- 层级属性（按需）
    province_code VARCHAR(20),
    province_name VARCHAR(100),
    city_code VARCHAR(20),
    city_name VARCHAR(100),
    
    -- SCD Type 2 字段
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    is_current BOOLEAN DEFAULT TRUE,
    
    -- ETL 元数据
    etl_time TIMESTAMP,
    pt STRING
  )
  PARTITIONED BY (pt STRING);
```

### 5.3 跨层调用规范

| 规则 | 说明 |
|------|------|
| **正向依赖** | ADS → DWS → DWD → ODS，禁止反向依赖 |
| **DIM 复用** | DIM 可被 DWD/DWS/ADS 任意层引用 |
| **不跨层** | ADS 不允许直接从 DWD 取数（必须经过 DWS） |
| **任务深度** | 从 ODS 到 ADS 任务深度不超过 10 层 |
| **跨域聚合** | ADS 层可跨数据域聚合，DWS 层应聚焦单域 |

### 5.4 分层检查清单

```markdown
## 分层建模检查清单

### ODS 层
- [ ] 每个源系统表对应一张 ODS 表
- [ ] 保留源系统全部字段
- [ ] 附加 ETL 元数据（etl_time, etl_batch_id）
- [ ] 按数据日期分区

### DWD 层
- [ ] 一个业务过程一张表
- [ ] 粒度统一，不混淆不同业务过程
- [ ] 已清洗：去重、过滤空值、统一格式
- [ ] 已关联维度：使用维度代理键
- [ ] 退化维度已合并

### DWS 层
- [ ] 按数据域 + 主题组织
- [ ] 宽表形态，包含常用维度和指标
- [ ] 派生指标已应用修饰词和时间周期
- [ ] 同主题公共指标已沉淀

### ADS 层
- [ ] 面向具体报表/产品/接口
- [ ] 跨数据域聚合在 ADS 层完成
- [ ] 报表所需维度齐全
- [ ] 报表展示指标完整

### DIM 层
- [ ] 一致性维度：跨业务过程共享
- [ ] SCD 策略明确（默认 Type 2）
- [ ] 代理键、自然键、描述属性齐全
```

---

## 6. OneData × Kimball 协作流程

### 6.1 端到端工作流

```
阶段1：OneData 自顶向下规划
─────────────────────────────────────────
① 业务调研 → 业务过程清单
② 数据域划分 → 数据域定义
③ 总线矩阵设计 → 业务过程 × 维度关系
④ 指标体系构建 → 原子指标 → 派生指标 → 衍生指标
⑤ 输出：数据域划分表、总线矩阵、指标字典

阶段2：Kimball 自底向上设计
─────────────────────────────────────────
⑥ 事实表设计 → 基于总线矩阵，识别度量和退化维度
⑦ 维度表设计 → 一致性维度表，SCD 策略
⑧ 模型集成 → 事实表 + 维度表 = 星型/雪花模型
⑨ 物理设计 → 分区、分布键、聚簇索引
⑩ 输出：维度模型、DDL、ETL 映射

阶段3：分层落地
─────────────────────────────────────────
⑪ ODS 落地 → 源系统数据接入
⑫ DWD 落地 → 基于 Kimball 设计的明细层
⑬ DWS 落地 → 基于指标体系的汇总层
⑭ ADS 落地 → 基于报表需求的应用层
⑮ DIM 落地 → 基于总线矩阵的一致性维度
```

### 6.2 协作分工

| 关注点 | OneData 负责 | Kimball 负责 |
|--------|-------------|-------------|
| **数据域** | ✅ 数据域划分、定义 | - |
| **业务过程** | ✅ 业务过程识别、定义 | - |
| **指标** | ✅ 指标体系（原子/派生/衍生） | - |
| **维度** | ✅ 维度识别（总线矩阵） | ✅ 维度表结构设计 |
| **事实表** | - | ✅ 事实表粒度、度量、维度关联 |
| **SCD** | - | ✅ SCD 策略选择 |
| **分层** | ✅ 分层架构规范 | ✅ 各层模型落地 |
| **命名** | ✅ 指标命名规范 | ✅ 表/字段命名规范 |

### 6.3 设计产物清单

| 阶段 | 产物 | 文件 | 消费方 |
|------|------|------|--------|
| OneData | 数据域划分表 | `data_domains.yaml` | 全部下游 |
| OneData | 业务过程清单 | `business_processes.yaml` | Kimball 建模 |
| OneData | 总线矩阵 | `bus_matrix.yaml` | 维度建模 |
| OneData | 指标字典 | `metrics_dictionary.yaml` | DWS 落地 |
| Kimball | 维度模型 | `dimensional_model.yaml` | DDL 生成 |
| Kimball | 事实表设计 | `fact_table_design.yaml` | DDL 生成 |
| Kimball | 维度表设计 | `dimension_table_design.yaml` | DDL 生成 |
| 落地 | 分层 DDL | `models/ods/*.sql` 等 | ETL 开发 |
| 落地 | 数据字典 | `schema_doc.md` | 数据治理 |

---

## 7. 工作流速查

### 7.1 OneData 速查

```bash
# 数据域划分
/onedata-methodology 划分数据域：电商业务
# 输出: data_domains.yaml

# 业务过程识别
/onedata-methodology 识别业务过程：交易域
# 输出: business_processes.yaml

# 总线矩阵设计
/onedata-methodology 设计总线矩阵：交易域 + 用户域 + 流量域
# 输入: data_domains.yaml
# 输出: bus_matrix.yaml

# 指标体系定义
/onedata-methodology 定义指标：交易域核心指标
# 输出: atomic_metrics.yaml, derived_metrics.yaml
```

### 7.2 Kimball 速查

```bash
# 维度建模
/model-design 基于 bus_matrix.yaml 设计维度模型

# Schema 文档
/schema-doc 基于设计结果生成完整数据字典
```

### 7.3 端到端

```bash
# 端到端建模（OneData + Kimball）
/skill-hub 端到端建模：电商数仓
# Step 1: OneData 数据域划分
# Step 2: OneData 总线矩阵
# Step 3: OneData 指标体系
# Step 4: Kimball 维度建模
# Step 5: 分层落地
```

---

## 8. 参考资料

- 《阿里大数据之路》—— 阿里巴巴数据技术及产品部
- 《OneData：阿里巴巴数据中台实践》—— 阿里数据中台团队
- 《数据仓库工具箱》（The Data Warehouse Toolkit）—— Ralph Kimball
- 阿里云 DataWorks 数据建模规范: https://help.aliyun.com/document_detail/137148.html
- 阿里云 MaxCompute 建模最佳实践: https://help.aliyun.com/document_detail/148460.html

---

**OneData 是数据中台的方法论基础，配合 Kimball 维度建模形成"规划 + 设计"的完整闭环。建议先掌握 OneData 的数据域划分和指标体系，再用 Kimball 进行表级设计。**
