---
name: refactor-methodology
description: |
  数仓重构方法论 - 5阶段完整重构流程。
  解决烟囱式开发的典型问题：模型重复、依赖混乱、资源浪费。
  触发词：数仓重构方法论、重构阶段、重构流程。
---

# 数仓重构方法论

## 重构背景

### 烟囱式开发的典型问题

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    烟囱式开发的典型乱象                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  问题1：模型重复建设                                                         │
│  ─────────────────────────────────────────────                              │
│  表现：                                                                      │
│  - 同一业务逻辑有多个实现（如订单明细有 3 个版本）                             │
│  - 不同团队各自建表，命名随意                                                │
│  - 存储重复，维护成本 3x                                                     │
│  影响：                                                                      │
│  - 资源浪费（存储、计算、人力）                                              │
│  - 数据口径不一致                                                            │
│  - 维护困难                                                                  │
│                                                                             │
│  问题2：依赖关系混乱                                                         │
│  ─────────────────────────────────────────────                              │
│  表现：                                                                      │
│  - ADS 层直接依赖 ODS 层（跨层依赖）                                          │
│  - 任务依赖路径过长（10+ 层）                                                │
│  - 循环依赖                                                                  │
│  影响：                                                                      │
│  - 数据质量无法保障                                                          │
│  - 任务失败影响范围大                                                        │
│  - 修改一处牵动全局                                                          │
│                                                                             │
│  问题3：命名不规范                                                           │
│  ─────────────────────────────────────────────                              │
│  表现：                                                                      │
│  - 表名随意：order_info_1, order_info_v2, tmp_order...                      │
│  - 字段名随意：amt, amount, total_amt, money...                              │
│  - 无数据域归属                                                              │
│  影响：                                                                      │
│  - 可读性差                                                                  │
│  - 无法统一管理                                                              │
│  - 新人上手困难                                                              │
│                                                                             │
│  问题4：缺少文档和负责人                                                     │
│  ─────────────────────────────────────────────                              │
│  表现：                                                                      │
│  - 表用途不明                                                                │
│  - 字段含义不清                                                              │
│  - 无责任人                                                                  │
│  影响：                                                                      │
│  - 知识流失                                                                  │
│  - 问题无人处理                                                              │
│  - 无法追溯                                                                  │
│                                                                             │
│  问题5：资源浪费                                                             │
│  ─────────────────────────────────────────────                              │
│  表现：                                                                      │
│  - 孤儿表：120 张表无下游消费                                                │
│  - 过期数据未清理                                                            │
│  - 低效 SQL 未优化                                                           │
│  影响：                                                                      │
│  - 存储浪费                                                                  │
│  - 计算资源浪费                                                              │
│  - 成本上升                                                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 重构5阶段总览

```
阶段                          核心目标                        产出物
─────────────────────────────────────────────────────────────────────────────

阶段1：现状盘点                建立重构基线                    资产清单
                              知道"有什么"和"多乱"            依赖地图
                                                              问题清单
                                                              优先级矩阵

阶段2：模型标准化              建立规范体系                    数据域划分
                              统一命名、分层、指标              总线矩阵
                                                              指标字典
                                                              迁移映射

阶段3：血缘与影响分析          理清依赖关系                    血缘图谱
                              评估重构影响                    影响报告
                                                              风险评估
                                                              迁移路径

阶段4：渐进式迁移              逐步迁移到新架构                迁移计划
                              保证业务连续性                  双跑方案
                                                              切换策略
                                                              回滚预案

阶段5：持续治理                建立长效机制                    治理流程
                              防止再次烟囱化                  质量监控
                                                              变更管控
                                                              复用机制

─────────────────────────────────────────────────────────────────────────────
```

---

## 阶段1：现状盘点

### 1.1 盘点目标

| 目标 | 具体内容 |
|------|---------|
| **建立资产清单** | 所有表、视图、任务、报表的完整清单 |
| **识别问题严重度** | 各类问题的数量和影响范围 |
| **确定重构优先级** | P0/P1/P2/P3 四级优先级 |
| **建立依赖地图** | 表与表、任务与任务之间的依赖关系 |

### 1.2 盘点维度

```yaml
盘点维度:
  
  # 1. 表资产盘点
  tables:
    fields:
      - name: "表名"
      - name: "所属数据库"
      - name: "数据量"
      - name: "存储大小"
      - name: "分区数"
      - name: "最后修改时间"
      - name: "表类型（表/视图）"
      - name: "所属层级（ODS/DWD/DWS/ADS/DIM/未分层）"
      - name: "所属数据域"
      - name: "负责人"
      - name: "是否有文档"
      - name: "是否有下游消费"
      
  # 2. 任务资产盘点
  tasks:
    fields:
      - name: "任务ID"
      - name: "任务名称"
      - name: "调度周期"
      - name: "依赖任务"
      - name: "源表"
      - name: "目标表"
      - name: "负责人"
      - name: "运行时长"
      - name: "失败率"
      
  # 3. 报表资产盘点
  reports:
    fields:
      - name: "报表名称"
      - name: "报表类型（BI/接口/API）"
      - name: "数据源表"
      - name: "使用用户"
      - name: "使用频率"
      - name: "负责人"
```

### 1.3 盘点方法

#### 方法1：自动化扫描

```bash
# 表资产扫描
SELECT 
    table_name,
    table_schema,
    table_type,
    engine,
    row_format,
    table_rows,
    data_length / 1024 / 1024 / 1024 AS size_gb,
    create_time,
    update_time
FROM information_schema.tables
WHERE table_schema IN ('ods', 'dwd', 'dws', 'ads', 'dim')
ORDER BY table_schema, table_name;

# 任务依赖扫描（DataWorks/DolphinScheduler）
# 从调度系统的 API 或数据库获取任务依赖关系

# 字段级血缘扫描
# 解析 SQL 的 FROM、JOIN、SELECT 子句获取字段来源
```

#### 方法2：访谈调研

```yaml
调研问卷:
  - question: "你的报表数据来源是哪些表？"
    audience: ["报表用户"]
    
  - question: "你的任务依赖哪些上游任务？"
    audience: ["ETL开发人员"]
    
  - question: "这个表的用途是什么？"
    audience: ["表负责人"]
    
  - question: "数据的口径定义是什么？"
    audience: ["数据分析人员"]
```

### 1.4 问题分类与评分

```yaml
问题分类:
  
  critical:      # 严重问题，立即处理
    - code: "C001"
      name: "跨层依赖"
      description: "ADS 直接依赖 ODS"
      scoring:
        impact_high: 10      # 影响报表 > 5 个
        impact_medium: 5      # 影响报表 1-5 个
        
    - code: "C002"
      name: "循环依赖"
      description: "任务 A 依赖 B，B 依赖 A"
      scoring:
        exists: 10           # 存在即严重
        
    - code: "C003"
      name: "数据口径冲突"
      description: "同一指标多个口径"
      scoring:
        conflict_count_3+: 10 # 3+ 个冲突口径
        conflict_count_2: 5   # 2 个冲突口径
        
  major:         # 重要问题，1-2周处理
    - code: "M001"
      name: "模型重复"
      description: "同一逻辑多个实现"
      scoring:
        dup_count_3+: 8       # 3+ 个重复
        dup_count_2: 4        # 2 个重复
        
    - code: "M002"
      name: "未归域"
      description: "表未归属数据域"
      scoring:
        percentage_30+: 8     # 30%+ 未归域
        percentage_10-30: 4   # 10-30% 未归域
        
    - code: "M003"
      name: "任务深度过大"
      description: "任务依赖深度 > 10 层"
      scoring:
        depth_15+: 8          # 15+ 层
        depth_10-15: 4        # 10-15 层
        
  minor:         # 一般问题，长期优化
    - code: "N001"
      name: "命名不规范"
      description: "不符合命名规范"
      scoring:
        percentage_50+: 5     # 50%+ 不规范
        
    - code: "N002"
      name: "缺少负责人"
      description: "表/任务无责任人"
      scoring:
        percentage_30+: 5     # 30%+ 无负责人
        
    - code: "N003"
      name: "缺少文档"
      description: "表/字段无说明"
      scoring:
        percentage_50+: 5     # 50%+ 无文档
        
    - code: "N004"
      name: "孤儿表"
      description: "无下游消费的表"
      scoring:
        count_50+: 5          # 50+ 个孤儿表
        count_10-50: 2        # 10-50 个
```

### 1.5 优先级矩阵

```
问题严重度 × 影响范围 = 重构优先级

严重度：
  - 高（Critical）：10 分
  - 中（Major）：5 分
  - 低（Minor）：2 分

影响范围：
  - 高：影响 5+ 报表/任务 → × 2
  - 中：影响 1-5 报表/任务 → × 1
  - 低：影响单个报表/任务 → × 0.5

优先级划分：
  - P0：总分 ≥ 15 → 立即处理
  - P1：总分 10-15 → 1-2周内处理
  - P2：总分 5-10 → 1-2月内处理
  - P3：总分 < 5 → 长期优化
```

---

## 阶段2：模型标准化

### 2.1 标准化目标

| 目标 | 具体内容 |
|------|---------|
| **建立数据域划分** | 所有表归属明确的数据域 |
| **建立总线矩阵** | 业务过程 × 维度的交叉关系 |
| **建立指标字典** | 原子指标、派生指标、衍生指标统一定义 |
| **建立命名规范** | 表/字段/任务命名统一标准 |
| **生成迁移映射** | 旧名 → 新名的映射关系 |

### 2.2 数据域划分（反向归域）

对于已有表，采用"反向归域"方法：

```yaml
反向归域流程:
  
  Step 1: 业务调研
    - 了解各表的业务用途
    - 识别业务过程（下单、支付、退款等）
    
  Step 2: 表归类
    - 根据表用途归入对应数据域
    - 无法归类的放入"待定域"
    
  Step 3: 域内整理
    - 按业务过程细分
    - 识别重复表
    
  Step 4: 评审确认
    - 与业务方确认归属
    - 与技术方确认合理性
    
示例:
  表: "ods_order_info"
  用途: "存储订单原始数据"
  业务过程: "下单"
  归域: "交易域"
  
  表: "dwd_user_behavior"
  用途: "用户行为明细"
  业务过程: "浏览/点击/加购"
  归域: "流量域"
```

### 2.3 命名规范化

```yaml
命名规范:
  
  # 表命名
  tables:
    pattern: "{layer}_{domain}_{entity}_{modifier}"
    examples:
      - "ods_trade_order_info"
      - "dwd_trade_order_detail"
      - "dws_trade_user_1d"
      - "ads_trade_sales_report"
      - "dim_user"
      
    forbidden:
      - "tmp_*"          # 临时表不应存在于数仓
      - "*_v1, *_v2"     # 版本号应通过注释或元数据管理
      - "*_copy"         # 复制表应清理
      - "*_bak"          # 备份表应清理
      
  # 字段命名
  fields:
    patterns:
      - "{entity}_id"    # 实体ID
      - "{entity}_sk"    # 代理键
      - "{entity}_nm"    # 名称
      - "{entity}_amt"   # 金额
      - "{entity}_cnt"   # 计数
      - "{action}_time"  # 时间戳
      - "{action}_date"  # 日期
      - "is_{flag}"      # 是否标志
      
    forbidden:
      - "amt, amount, money, total"   # 统一为 amount 或 amt
      - "cnt, count, num, quantity"   # 统一为 count 或 cnt
      - "dt, date, day"               # 统一为 date
      
  # 任务命名
  tasks:
    pattern: "task_{layer}_{domain}_{action}_{granularity}"
    examples:
      - "task_ods_trade_sync_hourly"
      - "task_dwd_trade_order_detail_daily"
      - "task_dws_trade_user_1d_daily"
```

### 2.4 迁移映射表

```yaml
# 旧名 → 新名映射
migration_mapping:

  tables:
    - old: "ods_order_info"
      new: "ods_trade_order"
      reason: "添加数据域前缀"
      
    - old: "dwd_order_detail_1"
      new: "dwd_trade_order_detail"
      reason: "合并重复表，添加数据域前缀"
      
    - old: "dwd_order_detail_2"
      new: "dwd_trade_order_detail"
      reason: "合并到统一模型"
      
    - old: "tmp_order_calc"
      new: "删除"
      reason: "临时表，应清理"
      
  fields:
    - table: "ods_trade_order"
      old: "amt"
      new: "order_amount"
      reason: "统一金额命名"
      
    - table: "ods_trade_order"
      old: "dt"
      new: "order_date"
      reason: "统一日期命名"
```

---

## 阶段3：血缘与影响分析

### 3.1 血缘类型

```
血缘层级:
  
  Level 1: 表级血缘
    ┌─────────────────────────────────────────┐
    │  ods_orders ──► dwd_orders ──► ads_report │
    └─────────────────────────────────────────┘
    
  Level 2: 任务级血缘
    ┌─────────────────────────────────────────┐
    │  task_ods_sync ──► task_dwd_transform    │
    │                  ──► task_dws_aggregate  │
    │                  ──► task_ads_report     │
    └─────────────────────────────────────────┘
    
  Level 3: 字段级血缘（最精细）
    ┌─────────────────────────────────────────┐
    │  ods.orders.amount ──► dwd.orders.amount │
    │                       ──► dws.total_amt  │
    │                       ──► ads.sales_amt  │
    └─────────────────────────────────────────┘
```

### 3.2 血缘扫描方法

#### SQL 解析法

```python
# SQL 血缘解析核心逻辑
def parse_sql_lineage(sql):
    lineage = {}
    
    # 1. 解析 FROM 子句（上游表）
    from_tables = extract_from_clause(sql)
    lineage['upstream_tables'] = from_tables
    
    # 2. 解析 JOIN 子句（关联表）
    join_tables = extract_join_clause(sql)
    lineage['join_tables'] = join_tables
    
    # 3. 解析 SELECT 子句（字段来源）
    select_fields = extract_select_clause(sql)
    lineage['field_sources'] = map_fields_to_sources(select_fields, from_tables)
    
    # 4. 解析 INSERT/CREATE（下游表）
    target_table = extract_target_table(sql)
    lineage['target_table'] = target_table
    
    return lineage

# 示例结果
{
    'upstream_tables': ['ods_orders', 'ods_users'],
    'join_tables': [{'table': 'ods_users', 'type': 'LEFT JOIN', 'key': 'user_id'}],
    'field_sources': {
        'order_id': 'ods_orders.order_id',
        'user_name': 'ods_users.user_name',
        'order_amount': 'ods_orders.amount'
    },
    'target_table': 'dwd_order_detail'
}
```

#### 调度系统提取法

```yaml
# 从调度系统获取任务依赖
# DataWorks API
GET /api/tasks/{task_id}/dependencies

# DolphinScheduler API  
GET /ds/projects/{projectId}/processDefinition/{processDefinitionId}

# 返回示例
{
    "task_id": "task_dwd_order_detail",
    "upstream_tasks": ["task_ods_order_sync", "task_ods_user_sync"],
    "downstream_tasks": ["task_dws_trade_summary", "task_ads_sales_report"]
}
```

### 3.3 影响分析流程

```yaml
影响分析流程:

  Step 1: 确定变更内容
    - 变更类型：新建/修改/删除/重命名
    - 变更对象：表/字段/任务
    
  Step 2: 查询血缘图谱
    - 查询上游依赖（影响数据来源）
    - 查询下游消费（影响数据产出）
    
  Step 3: 计算影响范围
    - 直接影响：一层下游
    - 间接影响：多层下游
    - 业务影响：最终报表/用户
    
  Step 4: 评估风险等级
    - 高风险：影响核心报表/大量用户
    - 中风险：影响非核心报表
    - 低风险：影响内部任务
    
  Step 5: 制定应对措施
    - 高风险：需要双跑验证、分批切换
    - 中风险：需要通知下游用户
    - 低风险：可直接变更
```

### 3.4 影响分析报告模板

```yaml
# impact_analysis_report.yaml
change_request:
  id: "CR-001"
  type: "表合并"
  description: "合并 dwd_order_detail_1/2/3 → dwd_trade_order_detail"
  requested_by: "数据团队"
  requested_at: "2024-01-15"

impact_scope:
  
  # 直接影响
  direct_impact:
    tables:
      - name: "dws_trade_summary"
        type: "直接消费"
        change: "源表变更"
        
    tasks:
      - name: "task_dws_trade_summary"
        type: "源任务"
        change: "需要修改SQL源表引用"
        
  # 间接影响
  indirect_impact:
    tables:
      - name: "ads_sales_report"
        path: ["dwd_order_detail_1", "dws_trade_summary", "ads_sales_report"]
        type: "间接消费"
        
      - name: "ads_order_analysis"
        path: ["dwd_order_detail_1", "dws_trade_summary", "ads_order_analysis"]
        type: "间接消费"
        
    reports:
      - name: "销售日报"
        importance: "核心报表"
        users: ["销售运营部", "管理层"]
        
      - name: "销售月报"
        importance: "核心报表"
        users: ["财务部"]
        
  # 用户影响
  user_impact:
    teams:
      - name: "销售运营部"
        reports: ["销售日报", "实时销售看板"]
        
      - name: "财务部"
        reports: ["销售月报", "收入统计"]
        
      - name: "数据分析部"
        tasks: ["数据分析任务"]

risk_assessment:
  level: "高风险"
  reason: "影响 5 个核心报表，涉及 3 个业务部门"
  
mitigation_plan:
  - phase: "双跑验证"
    duration: "1 周"
    action: "新旧模型并行运行，对比数据一致性"
    
  - phase: "分批切换"
    duration: "1 周"
    action: "先切换非核心报表，后切换核心报表"
    
  - phase: "监控告警"
    duration: "持续"
    action: "切换后监控数据差异，配置告警"
```

---

## 阶段4：渐进式迁移

### 4.1 迁移原则

```
迁移原则:
  
  1. 业务连续性优先
     - 保证报表正常产出
     - 不影响用户使用
     
  2. 渐进式迁移
     - 分批次迁移
     - 每批次可独立回滚
     
  3. 双跑验证
     - 新旧并行运行
     - 数据一致性对比
     
  4. 可回滚
     - 每步都有回滚预案
     - 回滚不影响业务
```

### 4.2 迁移策略对比

| 策略 | 适用场景 | 风险 | 资源消耗 |
|------|---------|------|---------|
| **一次性迁移** | 小规模、低风险 | 高 | 低 |
| **渐进式迁移** | 大规模、高风险 | 低 | 高（双跑） |
| **并行建设后切换** | 新建数仓 | 中 | 高 |
| **视图兼容过渡** | 有下游依赖 | 低 | 中 |

**推荐**：大规模数仓重构采用 **渐进式迁移 + 视图兼容过渡**。

### 4.3 迁移流程详解

```
迁移流程:

Phase 1: 新模型建设
────────────────────────────────────────────────────
  Task 1.1: 设计新模型结构
    - 定义表结构
    - 定义字段规范
    - 定义分区策略
    
  Task 1.2: 开发新ETL
    - 编写SQL代码
    - 配置调度任务
    
  Task 1.3: 单元测试
    - 测试数据质量
    - 测试性能
    
  产出: 新表DDL + 新ETL代码 + 测试报告
  
Phase 2: 双跑验证
────────────────────────────────────────────────────
  Task 2.1: 配置双跑任务
    - 新旧任务并行运行
    - 使用相同数据源
    
  Task 2.2: 数据对比
    - 行数对比
    - 数值对比
    - 分布对比
    
  Task 2.3: 性能对比
    - 运行时长
    - 资源消耗
    
  验收标准:
    - 数据一致率 > 99.99%
    - 性能不低于旧模型
    - 无数据质量问题
    
  产出: 双跑对比报告
  
Phase 3: 视图兼容
────────────────────────────────────────────────────
  Task 3.1: 创建兼容视图
    - 视图名 = 旧表名
    - 视图查询 = 新表
    
  Task 3.2: 通知下游用户
    - 发布变更公告
    - 提供切换指导
    
  Task 3.3: 验证兼容性
    - 下游任务验证
    - 下游报表验证
    
  产出: 兼容视图 + 变更公告
  
Phase 4: 下游切换
────────────────────────────────────────────────────
  Task 4.1: 分批切换
    - 先切换非核心下游
    - 后切换核心下游
    
  Task 4.2: 监控告警
    - 监控数据产出
    - 监控任务状态
    
  Task 4.3: 问题处理
    - 发现问题立即回滚
    - 分析问题原因
    
  产出: 切换记录 + 监控报告
  
Phase 5: 旧模型下线
────────────────────────────────────────────────────
  Task 5.1: 确认无消费
    - 检查下游依赖
    - 确认视图兼容有效
    
  Task 5.2: 停止旧任务
    - 停止调度
    - 保留代码备份
    
  Task 5.3: 清理旧表
    - 备份旧表数据
    - 删除旧表
    
  Task 5.4: 更新文档
    - 更新资产清单
    - 更新血缘图谱
    
  产出: 下线记录 + 更新后的资产清单
```

### 4.4 回滚预案

```yaml
回滚触发条件:
  - 双跑期间数据一致率 < 99.99%
  - 下游切换后任务失败率 > 5%
  - 用户报告数据问题
  - 性能下降超过 20%

回滚步骤:
  
  Step 1: 停止新模型任务
    action: "PAUSE task_new_model"
    expected_time: "立即"
    
  Step 2: 恢复旧模型任务
    action: "RESUME task_old_model"
    expected_time: "< 5 分钟"
    
  Step 3: 切换下游到旧模型
    action: |
      - 删除兼容视图或重定向到旧表
      - 更新下游任务配置
    expected_time: "< 15 分钟"
    
  Step 4: 验证恢复
    action: |
      - 运行下游任务
      - 检查报表产出
    expected_time: "< 30 分钟"
    
  Step 5: 通知用户
    action: |
      - 发布回滚公告
      - 说明回滚原因
      - 提供后续计划
```

---

## 阶段5：持续治理

### 5.1 治理框架

```yaml
治理框架:
  
  # 1. 组织保障
  organization:
    roles:
      - name: "数据架构师"
        responsibility: "模型设计评审、架构决策"
        
      - name: "数据开发工程师"
        responsibility: "模型开发、ETL维护"
        
      - name: "数据治理专员"
        responsibility: "规范检查、问题跟进"
        
      - name: "数据产品经理"
        responsibility: "需求管理、用户沟通"
        
    committees:
      - name: "数据架构评审委员会"
        members: ["数据架构师", "技术负责人", "业务负责人"]
        meeting_frequency: "每周"
        
  # 2. 流程保障
  processes:
    - name: "模型设计评审"
      trigger: "新建表/修改核心模型"
      steps:
        - "提交设计文档"
        - "架构师审核"
        - "评审会议讨论"
        - "批准后方可开发"
        
    - name: "变更审批"
      trigger: "修改已上线模型"
      steps:
        - "提交变更申请"
        - "影响分析"
        - "风险评估"
        - "审批通过"
        - "执行变更"
        
    - name: "定期审计"
      trigger: "每月"
      steps:
        - "资产盘点"
        - "规范检查"
        - "问题识别"
        - "整改跟踪"
```

### 5.2 规范检查自动化

```yaml
# 规范检查项
compliance_checks:
  
  daily_checks:
    - name: "任务状态检查"
      check: "任务失败率 < 5%"
      action: "告警通知"
      
    - name: "数据新鲜度检查"
      check: "核心表更新时间 < 24小时"
      action: "告警通知"
      
  weekly_checks:
    - name: "命名规范检查"
      check: "表名符合 {layer}_{domain}_{entity} 格式"
      action: "生成违规清单"
      
    - name: "孤儿表识别"
      check: "表有下游消费"
      action: "生成清理清单"
      
  monthly_checks:
    - name: "模型重复检测"
      check: "相似SQL逻辑检测"
      action: "生成合并建议"
      
    - name: "跨层依赖检查"
      check: "ADS → DWD → ODS 链路完整"
      action: "生成违规清单"
```

### 5.3 复用机制

```yaml
复用机制:
  
  # 1. 公共模型库
  public_models:
    - name: "dim_user"
      description: "用户一致性维度"
      owner: "数据平台"
      reuse_process: "申请 → 审核 → 使用"
      
    - name: "dim_product"
      description: "商品一致性维度"
      owner: "商品域"
      
    - name: "dim_date"
      description: "日期一致性维度"
      owner: "数据平台"
      
  # 2. 指标字典
  metrics_dictionary:
    atomic_metrics:
      - name: "订单数"
        definition: "COUNT(DISTINCT order_id)"
        owner: "交易域"
        
      - name: "支付金额"
        definition: "SUM(pay_amount)"
        owner: "交易域"
        
  # 3. 复用流程
  reuse_process:
    steps:
      - "需求评审时检查指标字典"
      - "检查是否可使用公共模型"
      - "如需新建，说明不复用原因"
      - "新建后纳入公共模型库"
```

### 5.4 变更管控

```yaml
变更管控:
  
  # 变更类型分级
  change_levels:
    - level: "P0"
      description: "核心模型变更"
      examples: ["修改交易事实表", "删除核心维度"]
      approval: "架构评审委员会 + 业务负责人"
      
    - level: "P1"
      description: "重要模型变更"
      examples: ["新增派生指标", "修改DWS表"]
      approval: "架构师 + 域负责人"
      
    - level: "P2"
      description: "一般变更"
      examples: ["新增字段", "修改非核心任务"]
      approval: "域负责人"
      
    - level: "P3"
      description: "日常变更"
      examples: ["修改注释", "优化SQL"]
      approval: "开发者"
      
  # 变更流程
  change_workflow:
    steps:
      - "提交变更申请（含影响分析）"
      - "对应级别审批"
      - "执行变更（含双跑验证）"
      - "变更后验证"
      - "更新文档"
      - "通知下游"
```

---

## 重构成功标准

```yaml
重构成功标准:
  
  # 1. 结构指标
  structure_metrics:
    - name: "模型重复率"
      before: "15%"
      target: "< 2%"
      
    - name: "未归域表比例"
      before: "25%"
      target: "< 5%"
      
    - name: "命名不规范比例"
      before: "35%"
      target: "< 5%"
      
    - name: "跨层依赖数"
      before: "35"
      target: "0"
      
  # 2. 效率指标
  efficiency_metrics:
    - name: "存储节省"
      before: "850 GB"
      target: "减少 30%+"
      
    - name: "任务平均深度"
      before: "12 层"
      target: "< 6 层"
      
    - name: "开发效率"
      before: "新建需求 5 天"
      target: "< 2 天（复用公共模型）"
      
  # 3. 质量指标
  quality_metrics:
    - name: "数据一致率"
      before: "95%"
      target: "> 99.9%"
      
    - name: "任务成功率"
      before: "90%"
      target: "> 99%"
      
  # 4. 治理指标
  governance_metrics:
    - name: "文档覆盖率"
      before: "40%"
      target: "> 90%"
      
    - name: "责任人覆盖率"
      before: "70%"
      target: "100%"
```

---

## 参考资料

- 《数据仓库工具箱》Ralph Kimball
- 《阿里大数据之路》—— OneData 方法论
- 《数据治理实践指南》—— DAMA 国际标准
- 数仓重构案例：Netflix、Airbnb、Uber 数据平台演进

---

**数仓重构是一项系统工程，建议从现状盘点建立基线，再逐步推进标准化、血缘分析、迁移和治理。**