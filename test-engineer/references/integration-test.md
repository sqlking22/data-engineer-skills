---
name: integration-test
description: |
  集成测试生成器 - 验证跨层/跨表数据一致性（DWD→DWS 对账、跨表关联、历史对比）。
  触发词：集成测试、对账测试、跨层一致性、汇总验证、数据对账。
argument: { description: "测试场景 或 modeling_package.yaml", required: true }
agent: general-purpose
allowed-tools: [Read, Grep, Glob, Edit, Write, Bash]
---

# 集成测试生成器

验证数据在跨层流转（ODS→DWD→DWS→ADS）、跨表关联时的一致性。位于测试金字塔中层。

## 工作流

1. **识别测试场景** — 解析对账对象（哪两层、哪些表、哪些维度）
2. **构建对账查询** — 两层数据按相同维度聚合后对比
3. **设定容忍度** — 浮点/近似计算场景设合理误差范围
4. **输出** — `tests/integration/test_cases_<scenario>.yaml`

## 测试类型

| 类型 | 场景 | 断言方式 |
|------|------|---------|
| 跨层对账 | DWD→DWS 汇总一致性 | 两层按相同维度聚合后金额/数量相等 |
| 跨表关联 | 事实表与维度表关联一致性 | 关联后字段非空、口径一致 |
| 历史对比 | 同环比 | 当期与上期差异在合理范围 |
| 口径校验 | 同一指标多路径计算 | 两条计算路径结果一致 |
| 总分核对 | 明细求和 = 汇总值 | `SUM(明细) = 汇总表值` |

## 输入

```
/integration-test 场景: DWD到DWS汇总对账
/integration-test --from-model
```

## 输出（test_cases.yaml）

```yaml
# tests/integration/test_cases_dwd_dws_recon.yaml
scenario: "DWD → DWS 用户交易汇总对账"
test_suite: integration
tolerance: 0.001            # 金额容忍度 0.1%（浮点/近似聚合）

cases:
  - id: IT_001
    name: "DWD 汇总额 = DWS 用户日汇总额"
    type: cross_layer_reconciliation
    dimensions: [user_sk, date_key]
    upstream:               # DWD 层
      table: dwd_trade_order_detail
      measure: "SUM(total_amount)"
      filter: "pt = '${bizdate}'"
    downstream:             # DWS 层
      table: dws_trade_user_1d
      measure: "pay_amount_1d"
      filter: "pt = '${bizdate}'"
    assert: "ABS(upstream - downstream) / NULLIF(upstream,0) <= ${tolerance}"
    severity: error
    fail_msg: "用户 {user_sk} 在 {date_key} 差异超容忍度：DWD={upstream}, DWS={downstream}"

  - id: IT_002
    name: "明细求和 = 汇总表总额"
    type: total_detail_check
    detail: "SELECT SUM(amount) FROM dwd_trade_order_detail WHERE pt='${bizdate}'"
    summary: "SELECT SUM(pay_amount_1d) FROM dws_trade_user_1d WHERE pt='${bizdate}'"
    assert: "ABS(detail - summary) <= 1.0"
    severity: error
```

## 容忍度规范

| 场景 | 建议容忍度 |
|------|-----------|
| 精确金额（DECIMAL） | 0（必须完全相等） |
| 浮点/比率计算 | ≤ 0.1% |
| 近似去重（APPROX_COUNT_DISTINCT） | ≤ 1% |
| 总分核对（大数求和） | ≤ 1.0（绝对值，防浮点累积） |

> 容忍度必须显式声明，不用"差不多就行"。详见 [test-standards.md](test-standards.md)。

## 要点

- **对账维度一致**：两层数据必须按**相同维度**聚合后对比（粒度对齐）
- **分区过滤一致**：上下游用相同的 pt 过滤，避免范围不对等
- **容忍度显式**：每条对账用例声明 tolerance

## 关联

- 规范：[test-standards.md](test-standards.md)
- 避坑：[best-practices.md](best-practices.md)（容忍度一刀切反例）
- 上游：modeling-assistant（`--from-model`，获取分层 schema）
