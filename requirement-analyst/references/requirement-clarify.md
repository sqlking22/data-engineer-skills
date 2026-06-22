---
name: requirement-clarify
description: |
  需求澄清器 - 基于 parsed_requirement 识别需求缺口与风险，生成澄清问题清单。
  触发词：需求澄清、需求缺口、澄清问题、风险评估、需求确认。
argument: { description: "requirement_parsed.yaml 或解析结果", required: true }
agent: general-purpose
allowed-tools: [Read, Grep, Glob, Write]
---

# 需求澄清器

基于解析结果识别**信息缺口**与**风险点**，按风险分级生成澄清问题清单，与业务方确认后补全需求。

## 工作流

1. **消费解析结果** — 读取 `requirement_parsed.yaml`
2. **缺口识别** — 按五大维度检查信息缺失/歧义
3. **风险分级** — 🔴 高风险（阻断）/ 🟡 中（建议）/ 🟢 低（可选）
4. **生成问题** — 将缺口转化为可向业务方提问的具体问题
5. **输出** — `clarifications/checklist.yaml` + 缺口报告

## 澄清检查维度

| 维度 | 检查方向 | 典型缺口 |
|------|---------|---------|
| **scope** 范围 | 时间范围、分析粒度、跨系统整合 | "历史多久？""订单级还是订单项级？" |
| **quality** 质量 | 一致性、异常处理、空值 | "误差容忍？""退款怎么处理？""空值策略？" |
| **security** 安全 | 敏感数据、权限、脱敏 | "有 PII/财务数据？""谁可访问？""需脱敏？" |
| **technical** 技术 | 技术栈、基础设施约束、源系统性能 | "目标数仓？""源库压力限制？" |
| **business_rules** 业务规则 | 指标口径、特殊情况、历史追溯 | "GMV 口径？""取消订单算吗？""等级变化要追溯？" |

## 输出 1：检查清单（checklist.yaml）

```yaml
# clarifications/checklist.yaml
clarification_dimensions:
  scope:
    questions:
      - "数据时间范围？（历史多久，增量还是全量）"
      - "分析粒度要求？（订单级、用户级、商品级）"
  quality:
    questions:
      - "数据一致性要求？（精确/可接受误差范围）"
      - "异常数据处理策略？（过滤/标记/估算）"
  business_rules:
    questions:
      - "指标计算口径是否有明确定义？"
      - "历史数据变更是否需要追溯？"
```

## 输出 2：缺口识别报告

```markdown
## 需求缺口识别报告

### 🔴 高风险缺口（必须澄清，阻断下游）
1. **订单金额口径**：是否包含运费？是否扣除优惠券？
2. **退款订单处理**：GMV 是否包含已退款订单？

### 🟡 中等风险缺口（建议澄清）
3. **数据时效**：T+1 的具体时间点？

### 💡 建议向业务方确认的问题
Q1: "GMV 的计算口径是什么？下单金额、支付金额、还是扣退款净额？"
```

## 风险分级原则

- 🔴 **高风险**：口径不明会导致返工的、涉及数据正确性的、有合规风险的 → 必须澄清
- 🟡 **中等**：影响实现细节但不阻断、有合理默认值的 → 建议澄清
- 🟢 **低风险**：技术偏好、可后补的 → 可选

## 要点

- **只识别+提问，不替业务方决策**：缺口转化为问题，由业务方回答
- **标注工具权限**：本命令只读解析结果 + 写 checklist，不修改源数据
- **澄清结果回填**：业务方确认后，更新 parsed_requirement 再进 transform

## 关联

- 上游：[/requirement-parser](requirement-parser.md) 的解析结果
- 规范参考：[requirement-standards.md](requirement-standards.md)
- 下游：[/requirement-transform](requirement-transform.md) 转化为 hints
