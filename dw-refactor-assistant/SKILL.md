---
name: dw-refactor-assistant
description: |
  数仓重构助手 - 端到端数仓重构工作流。解决烟囱式开发导致的模型重复、依赖混乱、资源浪费问题。
  包含5个核心阶段：现状盘点 → 模型标准化 → 血缘分析 → 渐进迁移 → 持续治理。
  当用户需要重构现有数据仓库、治理数仓乱象、建立规范体系时触发。
  触发词：数仓重构、模型治理、烟囱式开发、血缘分析、资产盘点、迁移方案、重复模型。
---

# 数仓重构助手

从烟囱式开发到规范化数仓的完整重构工作流。5个阶段：现状盘点 → 模型标准化 → 血缘分析 → 渐进迁移 → 持续治理。

## 架构概览

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          数仓重构助手架构                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   现有数仓（烟囱式开发）                                                      │
│   ┌──────────────────────────────────────────────────────────┐              │
│   │  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐           │              │
│   │  │烟囱1│  │烟囱2│  │烟囱3│  │烟囱4│  │烟囱N│  ...        │              │
│   │  └──┬──┘  └──┬──┘  └──┬──┘  └──┬──┘  └──┬──┘           │              │
│   │     │        │        │        │        │                │              │
│   │     └────────┴────────┴────────┴────────┘                │              │
│   │                       │                                   │              │
│   │            重复建设、依赖混乱、资源浪费                      │              │
│   └──────────────────────────────────────────────────────────┘              │
│                              │                                              │
│                              ▼                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │                    阶段1：现状盘点                                    │   │
│   │   /asset-inventory  →  资产清单、依赖地图、问题清单                   │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │                    阶段2：模型标准化                                  │   │
│   │   /model-standardize  →  数据域、总线矩阵、指标字典、命名规范         │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │                    阶段3：血缘与影响分析                               │   │
│   │   /lineage-scan · /dup-detection · /impact-analysis                  │   │
│   │   → 血缘图谱、重复模型、影响范围、迁移路径、风险评估                   │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │                    阶段4：渐进式迁移                                  │   │
│   │   /refactor-plan  →  迁移计划、双跑方案、切换策略、回滚预案           │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │                    阶段5：持续治理                                    │   │
│   │   /governance-setup  →  治理流程、质量监控、变更管控、复用机制        │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│   重构后数仓（规范化体系）                                                   │
│   ┌──────────────────────────────────────────────────────────┐              │
│   │                    ADS 应用层                            │              │
│   ├──────────────────────────────────────────────────────────┤              │
│   │                    DWS 汇总层                            │              │
│   ├──────────────────────────────────────────────────────────┤              │
│   │                    DWD 明细层  ←── DIM 维度层            │              │
│   ├──────────────────────────────────────────────────────────┤              │
│   │                    ODS 贴源层                            │              │
│   └──────────────────────────────────────────────────────────┘              │
│                                                                             │
│            规范化、可复用、可追溯、可治理                                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 参考资料导航

| 何时读取 | 文件 | 内容 | 场景 |
|---------|------|------|------|
| 重构前 | [references/refactor-methodology.md](references/refactor-methodology.md) | 5阶段重构方法论 | 了解重构全貌 |
| 资产盘点时 | [references/asset-inventory-template.md](references/asset-inventory-template.md) | 盘点模板、检查清单 | 执行现状盘点 |
| 模型标准化时 | [references/model-standardize.md](references/model-standardize.md) | 反向归域、命名整改、迁移映射 | 执行阶段2标准化 |
| 重复检测时 | [references/dup-detection.md](references/dup-detection.md) | 表名/结构/逻辑重复检测、合并建议 | 识别烟囱式重复 |
| 血缘分析时 | [references/lineage-analysis-guide.md](references/lineage-analysis-guide.md) | 血缘扫描方法、工具 | 梳理依赖关系 |
| 迁移执行时 | [references/migration-playbook.md](references/migration-playbook.md) | 迁移步骤、回滚预案 | 执行迁移 |
| 治理建设时 | [references/governance-framework.md](references/governance-framework.md) | 治理流程、制度 | 建立长效机制 |
| **最佳实践指南** | [references/best-practices.md](references/best-practices.md) | **重构优先级判定、双跑阈值、灰度切换、回滚触发** |
| 使用示例 | [examples/example-inventory.md](examples/example-inventory.md) | 资产盘点完整示例 | 参考实际输出 |

---

## 阶段1：现状盘点

### 核心目标

建立重构基线，回答三个问题：
1. **有什么** — 数仓资产清单
2. **多乱** — 问题严重程度
3. **优先级** — 从哪里开始重构

### 核心功能：/asset-inventory

**使用场景**：
- 数仓重构前摸底
- 定期资产盘点
- 治理现状评估

**输入格式**：
```
/asset-inventory
数据源：AnalyticDB MySQL / MaxCompute
范围：指定数据库或全库
输出：资产清单 + 问题报告
```

**输出内容**：

#### 1. 资产清单

```yaml
# asset_inventory.yaml
inventory_date: "2024-01-15"
scope: "adb_mysql.production"

summary:
  total_tables: 1250
  total_views: 320
  total_tasks: 450
  total_size_gb: 850
  
by_layer:
  ods: { tables: 180, size_gb: 200 }
  dwd: { tables: 350, size_gb: 280 }
  dws: { tables: 420, size_gb: 250 }
  ads: { tables: 300, size_gb: 120 }
  
by_domain:
  trade: { tables: 320, tasks: 120 }
  user: { tables: 180, tasks: 80 }
  product: { tables: 150, tasks: 60 }
  traffic: { tables: 280, tasks: 100 }
  unknown: { tables: 320, tasks: 90 }  # 未归域

tables:
  - name: "ods_order_info"
    layer: "ODS"
    domain: "交易域"
    owner: "张三"
    size_gb: 15.2
    rows: 150000000
    partitions: 730
    last_modified: "2024-01-10"
    
  - name: "dwd_order_detail_1"
    layer: "DWD"
    domain: "交易域"
    owner: "张三"
    # 问题标记
    issues:
      - "命名不符合规范：应为 dwd_trade_order_detail"
      - "粒度不明确：与 dwd_order_detail_2 重复"
```

#### 2. 问题清单

```yaml
# issues_report.yaml
generated_at: "2024-01-15"

critical_issues:
  - id: "ISS-001"
    type: "模型重复"
    severity: "高"
    description: "订单明细存在3个相似模型：dwd_order_detail_1/2/3"
    impact: "重复存储 50GB，维护成本 3x"
    recommendation: "合并为一个标准模型"
    
  - id: "ISS-002"
    type: "跨层依赖"
    severity: "高"
    description: "ADS 层 ads_sales_report 直接依赖 ODS 层表"
    impact: "无法保证数据质量，下游影响 5 个报表"
    recommendation: "重构为 ADS → DWS → DWD → ODS"

  - id: "ISS-003"
    type: "未归域"
    severity: "中"
    description: "320 张表未归属任何数据域"
    impact: "无法进行统一管理"
    recommendation: "按业务过程归域"

common_issues:
  naming_nonstandard: 450      # 命名不规范
  missing_owner: 180            # 缺少负责人
  no_documentation: 520         # 缺少文档
  duplicated_logic: 85          # 重复逻辑
  cross_layer_dependency: 35    # 跨层依赖
  orphan_tables: 120            # 孤儿表（无下游消费）
```

#### 3. 优先级矩阵

```yaml
# refactor_priority.yaml
priorities:
  P0_critical:  # 立即处理
    - issue: "跨层依赖 ADS→ODS"
      reason: "影响数据质量，下游报表风险高"
    - issue: "核心交易链路模型重复"
      reason: "存储和维护成本高"
      
  P1_high:      # 1-2周内处理
    - issue: "320张表未归域"
      reason: "影响统一管理"
    - issue: "85个重复逻辑"
      reason: "维护成本高"
      
  P2_medium:    # 1-2月内处理
    - issue: "450个命名不规范"
      reason: "影响可读性和治理"
    - issue: "180个缺少负责人"
      reason: "影响责任划分"
      
  P3_low:       # 长期优化
    - issue: "520个缺少文档"
      reason: "影响知识传承"
    - issue: "120个孤儿表"
      reason: "资源浪费"
```

---

## 阶段2：模型标准化

### 核心目标

建立规范体系，统一：
- 数据域划分
- 总线矩阵
- 指标字典
- 命名规范

### 核心功能：/model-standardize

**使用场景**：
- 为现有模型建立规范
- 识别不符合规范的模型
- 生成规范化迁移方案

**输入格式**：
```
/model-standardize
输入：现有资产清单
方法：OneData 建模理论
输出：数据域划分 + 总线矩阵 + 指标字典 + 迁移映射
```

**输出内容**：

#### 1. 数据域划分（基于现有模型反向归域）

```yaml
# domain_mapping.yaml
data_domains:
  - name: "交易域"
    code: "trade"
    tables:
      existing:
        - "ods_order_info"
        - "dwd_order_detail_1"
        - "dwd_order_detail_2"
        - "dws_trade_summary"
        - "ads_sales_report"
      recommended:
        - "ods_trade_order"
        - "dwd_trade_order_detail"
        - "dws_trade_user_1d"
```

#### 2. 迁移映射表

```yaml
# migration_mapping.yaml
migrations:
  - from: "dwd_order_detail_1"
    to: "dwd_trade_order_detail"
    actions:
      - "重命名表"
      - "调整字段顺序"
      - "添加数据域前缀"
    breaking_changes: true
    downstream_impact:
      - "ads_sales_report"
      - "ads_order_analysis"
```

---

## 阶段3：血缘与影响分析

### 核心目标

理清依赖关系，评估重构影响。

### 核心功能

| 命令 | 功能 | 输出 |
|------|------|------|
| `/lineage-scan` | 扫描表/任务/字段级血缘 | 血缘图谱 |
| `/impact-analysis` | 分析重构影响范围 | 影响报告 |
| `/dup-detection` | 检测重复模型/相似逻辑 | 重复清单 |

**血缘扫描示例**：

```bash
/lineage-scan
目标：dwd_order_detail_1
范围：上游 3 层 + 下游 5 层
输出：血缘图谱 + 影响范围
```

**输出血缘图谱**：

```yaml
# lineage_graph.yaml
root: "dwd_order_detail_1"

upstream:  # 上游依赖
  - table: "ods_order_info"
    type: "直接依赖"
    join_type: "INNER JOIN"
    fields_used: ["order_id", "user_id", "amount"]
    
  - table: "ods_order_items"
    type: "直接依赖"
    join_type: "LEFT JOIN"
    fields_used: ["product_id", "quantity"]

downstream:  # 下游消费
  - table: "dws_trade_summary"
    type: "直接消费"
    tasks: ["task_dws_trade_1d"]
    
  - table: "ads_sales_report"
    type: "间接消费"
    path: ["dwd_order_detail_1", "dws_trade_summary", "ads_sales_report"]
    tasks: ["task_ads_sales_report"]
    reports: ["销售日报", "销售月报"]
    users: ["销售运营部", "财务部"]
```

**影响分析报告**：

```yaml
# impact_report.yaml
change: "合并 dwd_order_detail_1/2/3 → dwd_trade_order_detail"

impact_summary:
  downstream_tables: 12
  downstream_tasks: 8
  downstream_reports: 5
  affected_users: ["销售运营", "财务", "数据分析"]
  
breaking_changes:
  - change: "表名变更"
    impact: "下游 8 个任务需要修改"
    effort: "2 人天"
    
  - change: "字段顺序调整"
    impact: "下游 5 个报表需要验证"
    effort: "1 人天"
    
mitigation:
  - "创建视图兼容旧表名"
  - "双跑验证"
  - "分批次切换下游任务"
```

---

## 阶段4：渐进式迁移

### 核心目标

逐步迁移到新架构，保证业务连续性。

### 核心功能：/refactor-plan

**使用场景**：
- 制定迁移计划
- 评估迁移风险
- 准备回滚预案

**输入格式**：
```
/refactor-plan
目标：重构交易域模型
方式：渐进式迁移
约束：保证业务连续性
输出：迁移计划 + 双跑方案 + 回滚预案
```

**输出迁移计划**：

```yaml
# migration_plan.yaml
project: "交易域模型重构"
duration: "4 周"
approach: "渐进式迁移"

phases:
  - phase: 1
    name: "新模型建设"
    duration: "1 周"
    tasks:
      - "创建 dwd_trade_order_detail"
      - "配置数据同步"
      - "单元测试"
    deliverables:
      - "新表 DDL"
      - "ETL 代码"
      - "测试报告"
      
  - phase: 2
    name: "双跑验证"
    duration: "1 周"
    tasks:
      - "新旧模型并行运行"
      - "数据一致性对比"
      - "性能对比"
    criteria:
      - "数据一致率 > 99.99%"
      - "性能不低于旧模型"
      
  - phase: 3
    name: "下游切换"
    duration: "1 周"
    tasks:
      - "切换下游任务到新模型"
      - "创建旧表视图兼容"
      - "监控告警"
    rollback_trigger:
      - "数据差异 > 0.01%"
      - "任务失败率 > 5%"
      
  - phase: 4
    name: "旧模型下线"
    duration: "1 周"
    tasks:
      - "下线旧模型任务"
      - "清理旧表"
      - "更新文档"
```

**回滚预案**：

```yaml
# rollback_plan.yaml
triggers:
  - "双跑期间数据差异 > 0.01%"
  - "下游切换后任务失败率 > 5%"
  - "用户报告数据问题"

rollback_steps:
  - step: 1
    action: "停止新模型任务"
    command: "PAUSE task_dwd_trade_order_detail"
    
  - step: 2
    action: "恢复旧模型任务"
    command: "RESUME task_dwd_order_detail_1"
    
  - step: 3
    action: "切换下游到旧模型"
    command: "UPDATE downstream_tasks SET source = 'dwd_order_detail_1'"
    
  - step: 4
    action: "验证恢复"
    command: "VALIDATE all_downstream_reports"

communication:
  - "通知下游用户回滚原因"
  - "更新迁移状态看板"
  - "记录回滚日志"
```

---

## 阶段5：持续治理

### 核心目标

建立长效机制，防止再次烟囱化。

### 核心功能：/governance-setup

**使用场景**：
- 建立治理流程
- 配置质量监控
- 设置变更管控

**输出治理框架**：

```yaml
# governance_framework.yaml
components:
  # 1. 变更管控
  change_control:
    review_process:
      - "模型设计评审"
      - "代码审查"
      - "影响分析"
    approval_required:
      - "新建表"
      - "修改核心模型"
      - "删除表"
      
  # 2. 质量监控
  quality_monitoring:
    checks:
      - "数据新鲜度监控"
      - "数据量波动监控"
      - "数据一致性监控"
    alert_channels:
      - "钉钉群"
      - "邮件"
      
  # 3. 复用机制
  reuse_mechanism:
    model_registry:
      - "公共模型库"
      - "指标字典"
      - "维度字典"
    reuse_process:
      - "需求评审时检查是否可复用"
      - "新建模型需说明不复用原因"
      
  # 4. 定期审计
  periodic_audit:
    frequency: "每月"
    scope:
      - "命名规范检查"
      - "重复模型检测"
      - "孤儿表识别"
    output: "治理报告"
```

---

## 工作流速查

### 端到端重构流程

```bash
# 完整数仓重构
/dw-refactor-assistant 端到端重构：交易域数仓
# Step 1: 现状盘点 → /asset-inventory
# Step 2: 模型标准化 → /model-standardize
# Step 3: 血缘与影响分析 → /lineage-scan · /dup-detection · /impact-analysis
# Step 4: 迁移执行 → /refactor-plan
# Step 5: 治理建设 → /governance-setup
```

### 分阶段使用

```bash
# 阶段1：现状盘点
/asset-inventory 盘点 AnalyticDB MySQL 全库

# 阶段2：模型标准化
/model-standardize 基于资产清单建立规范

# 阶段3：血缘与影响分析
/lineage-scan 扫描 dwd_order_detail_1 的血缘
/dup-detection 检测交易域的重复模型
/impact-analysis 分析合并该表的影响

# 阶段4：迁移执行
/refactor-plan 制定交易域迁移方案

# 阶段5：持续治理
/governance-setup 建立数仓治理体系
```

---

## 常见场景

### 场景1：识别烟囱式开发的重复模型

```bash
/dup-detection 检测交易域的重复模型
# 输出：重复模型清单、相似度评分、合并建议
```

### 场景2：评估模型下线影响

```bash
/impact-analysis 分析下线 dwd_old_order 的影响
# 输出：下游任务、报表、用户、风险等级
```

### 场景3：制定迁移方案

```bash
/refactor-plan
目标：将烟囱模型合并到标准模型
范围：订单相关的 3 个重复模型
方式：渐进式迁移
```

---

## 故障排除

### 血缘扫描不完整

1. 检查 SQL 解析是否覆盖所有语法
2. 确认调度系统的任务依赖关系
3. 补充手动维护的血缘关系

### 迁移后数据不一致

1. 检查 SQL 逻辑是否完全等价
2. 验证数据类型转换
3. 对比新旧模型的数据样例

### 下游切换失败

1. 触发回滚预案
2. 检查下游任务的依赖配置
3. 验证新模型的访问权限

---

## 路线图

### v1.0.0 (当前)
- ✅ 资产盘点 (/asset-inventory)
- ✅ 模型标准化 (/model-standardize)
- ✅ 血缘扫描 (/lineage-scan)
- ✅ 重复检测 (/dup-detection)
- ✅ 影响分析 (/impact-analysis)
- ✅ 迁移计划 (/refactor-plan)
- ✅ 治理框架 (/governance-setup)

### v1.1.0 (计划)
- 🔄 自动化血缘扫描脚本
- 🔄 迁移进度看板

### v2.0.0 (计划)
- 📝 影响分析可视化
- 📝 治理自动化检查
- 📝 与调度系统集成

---

## 最佳实践

> 📖 **完整最佳实践指南**：[references/best-practices.md](references/best-practices.md) — 包含重构优先级判定、双跑阈值、灰度切换、回滚触发。

### 0. 速查卡片

| 卡片 | 核心原则 |
|------|---------|
| 📊 先盘点后重构 | 没有资产清单和优先级，不要动手 |
| 🛡️ 业务连续性优先 | 重构不能影响下游报表和用户 |
| 🔄 渐进式迁移 | 一次性迁移风险太高，分批推进 |
| 🏃 双跑验证 | 新旧并行运行，数据一致后才能切 |
| ⏪ 可回滚 | 每步操作都有回滚预案，触发条件明确 |
| 🔍 影响分析必做 | 任何变更前先评估下游影响 |
| 📣 沟通到位 | 下游用户必须提前知晓变更时间 |
| ⚠️ 避免过度重构 | 只重构真正有问题的部分 |

### 1. 重构前先盘点

- 用 [scripts/scan-tables.sh](scripts/scan-tables.sh) 生成资产清单
- 用 [scripts/check-naming.sh](scripts/check-naming.sh) 检查命名违规
- 用 [scripts/detect-duplicates.sh](scripts/detect-duplicates.sh) 识别重复模型
- 输出问题清单后按 P0/P1/P2/P3 排优先级

### 2. 双跑期合理阈值

- 主键匹配：100%（基础）
- 行数对比：整数精确，允许 ±0.01% 差异
- 金额对比：绝对差异 < 0.01 元或相对 < 0.01%
- 状态枚举：100% 一致
- 时间戳：允许 1 秒内差异

### 3. 灰度切换策略

- 阶段 1：内部用户灰度（5%），3 天
- 阶段 2：小流量用户（20%），3 天
- 阶段 3：全量用户（100%），持续
- 任一阶段失败立即回滚

### 4. 回滚触发条件（明确化）

- 双跑期数据一致率 < 99.9%
- 下游任务失败率 > 5%
- 用户报告数据问题
- 性能下降 > 50%

---

**数仓重构是一项系统工程，建议从现状盘点开始，建立基线后再逐步推进。**
