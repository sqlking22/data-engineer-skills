---
name: requirement-parser
description: |
  需求解析器 - 将自然语言业务需求结构化为 requirement_parsed.yaml（实体/过程/指标/维度/数据源/约束）。
  触发词：需求解析、需求结构化、提取实体指标、业务需求梳理、会议纪要转需求。
argument: { description: "业务场景描述、需求文档或会议纪要", required: true }
agent: general-purpose
allowed-tools: [Read, Grep, Glob, Edit, Write, Bash]
---

# 需求解析器

将自然语言业务需求解析为结构化的 `requirement_parsed.yaml`，供 `/requirement-clarify`（澄清缺口）与 `/requirement-transform`（转化为下游 hints）消费。

## 工作流

1. **需求理解** — 通读输入，识别业务域与核心目标
2. **实体/过程识别** — 提取核心业务实体与业务过程
3. **指标/维度提取** — 从"想看什么"提取分析指标与维度
4. **数据源推断** — 推断数据来源、系统、规模
5. **约束识别** — 识别时效、精度、保留期、用户群体
6. **输出** — 生成 `requirements/parsed/requirement_parsed.yaml`

## 解析维度

| 维度 | 识别要点 | 示例 |
|------|---------|------|
| 业务实体 | 核心数据对象及其关键属性 | 订单(订单ID/金额/状态/时间)、用户、商品 |
| 业务过程 | 业务活动事件（动词） | 下单、支付、发货、退款 |
| 分析指标 | 可量化的度量（含口径） | GMV=SUM(订单金额)、订单量、客单价 |
| 分析维度 | 切分视角 | 日期、地区、用户等级、类目 |
| 数据源 | 数据来自哪个系统/库/日志 | 订单系统(MySQL)、行为埋点(JSON) |
| 时效要求 | 新鲜度 | T+1、准实时、实时 |
| 数据量 | 规模估算 | 日增100万、总量10亿 |
| 用户群体 | 谁消费 | 管理层、分析师、运营 |

## 输出规范（requirement_parsed.yaml）

```yaml
version: "1.0"
parse_result:
  business_domain: "电商销售分析"
  business_goal: "监控销售业绩，支持运营决策"

  entities:                       # 业务实体 + 关键属性
    - name: "订单"
      type: "业务实体"
      attributes: ["订单ID", "用户ID", "订单金额", "下单时间", "订单状态"]

  business_processes:             # 业务过程 + 涉及实体
    - name: "下单"
      entities_involved: ["订单", "用户", "商品"]

  metrics:                        # 指标 + 口径 + 维度 + 频率
    - name: "GMV"
      alias: "成交总额"
      formula: "SUM(订单金额)"
      dimensions: ["日期", "地区", "用户等级"]
      frequency: "每日"

  data_sources:                   # 数据源 + 系统 + 规模
    - type: "MySQL (OLTP 源)"
      system: "订单系统"
      tables: ["orders", "order_items"]
      estimated_size: "日增100万订单"

  requirements:                   # 约束
    freshness: "T+1"
    retention: "3年"
    accuracy: "精确到分"
    users: ["销售运营", "数据分析师", "管理层"]
```

## 解析要点

- **指标口径要显式**：GMV 是下单金额、支付金额、还是扣退款净额？解析阶段标注歧义，交 clarify 确认。
- **数据源标注性质**：`MySQL` 在此指业务侧 OLTP 源（待同步入仓），非数仓底座。本套件生成的 SQL 仅面向 ADB MySQL / MaxCompute。
- **粒度尽早明确**：订单级 vs 订单项级，影响后续建模。
- **不预决实现**：只解析"需要什么"，不写事实表结构/SCD 策略（那是 transform 之后、由 modeling 决定）。

## 关联

- 规范参考：[requirement-standards.md](requirement-standards.md)
- 下游：[/requirement-clarify](requirement-clarify.md) 识别缺口、[/requirement-transform](requirement-transform.md) 转化为 hints
