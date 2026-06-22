---
name: requirement-transform
description: |
  需求转化器 - 将确认后的需求转化为下游可消费的需求意图（hints）+ 调用指令。
  触发词：需求转化、技术规格、需求包、下游指令、requirement_package。
argument: { description: "确认后的 requirement_parsed.yaml + clarifications", required: true }
agent: general-purpose
allowed-tools: [Read, Grep, Glob, Edit, Write, Bash]
---

# 需求转化器

将确认后的需求转化为 `requirement_package.yaml`（含下游 hints + 调用指令），驱动 modeling/sql/dq/test 模块。

## 职责边界（核心）

> transform 阶段只产出**需求意图/关注点**（hints），供下游模块据此决策；**不预决建模结构、SCD 策略、同步实现、质量规则**——这些由下游模块各自决定。

| ✅ 产出（意图级 hints） | ❌ 不产出（实现级，归下游） |
|------------------------|---------------------------|
| 需分析的业务过程、期望粒度 | 事实表字段结构、星型模型 |
| 需保留历史的属性 | SCD Type 2（由 modeling 决定） |
| 时效要求、数据源、规模 | 增量/水印/upsert 方案（由 ETL 决定） |
| 质量关注点（订单唯一、金额合理） | 具体 rule type/SQL（由 dq 决定） |

## 工作流

1. **消费确认结果** — 读取 parsed_requirement + clarifications
2. **提炼意图** — 把需求转化为下游 hints（不写实现）
3. **生成调用指令** — 编排下游 skill 调用顺序
4. **打包输出** — `requirement_package.yaml` + `outputs/skill_commands.md`

## 输出（requirement_package.yaml）

```yaml
version: "1.0"
metadata:
  project_name: "电商销售分析"
  generated_by: "requirement-analyst"
  upstream_package: null

# 下游 hints（意图级，不预决实现）
modeling_hints:
  business_processes: ["下单", "支付"]
  analysis_grain: "订单项级别"
  dimensions_of_interest: ["用户", "商品", "日期", "地区"]
  key_measures: ["订单金额", "订单数量"]
  history_tracking:                  # 需保留历史的属性（SCD 策略由建模定）
    - entity: "用户"
      attributes: ["用户等级", "城市"]

sync_hints:
  source_systems:
    - system: "订单系统"
      type: "MySQL (OLTP 源，待同步入 ADB)"
  freshness_requirement: "T+1（每天 08:00 前出数据）"
  data_volume: "日增约 100 万订单"

quality_hints:
  - concern: "订单标识唯一、非空"
    importance: "critical"
  - concern: "金额合理（非负、合理范围）"
    importance: "high"

# 联动参数（供下游 --from-requirement 注入）
downstream_specs:
  - target: "modeling-assistant"
    input_file: "requirement_package.yaml"
    command: "/modeling-assistant --from-requirement"
```

## 输出（outputs/skill_commands.md）

```bash
# 根据需求转化结果，建议按以下顺序调用下游 Skill：

## Step 1: 数据建模
/modeling-assistant --from-requirement
# 消费 modeling_hints，决定事实表/维度表结构、SCD 策略

## Step 2: SQL 开发
/sql-assistant --from-model
# 消费 modeling_package，生成 DDL 与 ETL SQL

## Step 3: 数据质量
/dq-assistant --from-sql
# 消费 sql_package + quality_hints，生成质量规则
```

## 要点

- **hints 是"需求意图"**：描述"需要什么"，不规定"怎么做"
- **口径要清晰传递**：澄清确认的指标口径写入 hints，避免下游重新猜测
- **不越界**：不写表结构/SCD type/水印/rule type，避免预决下游实现

## 关联

- 上游：[/requirement-parser](requirement-parser.md) + [/requirement-clarify](requirement-clarify.md)
- 规范参考：[requirement-standards.md](requirement-standards.md)
- 下游：modeling-assistant（`--from-requirement`）、sql-assistant
- 联动配置：`skill-connections.yaml` 的 `full_development_pipeline`
