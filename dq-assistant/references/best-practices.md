---
name: dq-assistant-best-practices
description: |
  数据质量最佳实践 - 团队经验沉淀，包含规则设计反模式、阈值设置技巧、空值与异常值处理。
  触发词：数据质量、最佳实践、避坑指南、质量规则、阈值设置、空值处理、异常检测。
---

# 数据质量最佳实践

> 本文沉淀团队在数据质量管理方面的实战经验，配套 [SKILL.md](../SKILL.md) 一起使用。
> 详细规范见 [data-quality-standards.md](data-quality-standards.md)。

## 1. 核心原则速查

| # | 核心原则 | 说明 |
|---|---------|------|
| 1 | **预防胜于检查** | 在 ETL 源头约束，比事后检查更有效 |
| 2 | **分级管理** | 高/中/低优先级规则对应不同严重度和响应 |
| 3 | **分层监控** | 不同层级（核心/边缘）采用不同检查频率 |
| 4 | **指标可量化** | 质量评分可计算、可对比、可追踪 |
| 5 | **告警分级** | 不同严重度对应不同告警渠道和响应时效 |
| 6 | **持续改进** | 质量规则随业务变化而调整 |
| 7 | **Owner 明确** | 每个表/规则必须有明确负责人 |
| 8 | **可解释性** | 异常原因可追溯，规则可被业务方理解 |

## 2. 反模式与避坑指南

### ❌ 反例 1：规则一刀切

```yaml
# 错误：所有规则都用同一阈值
rules:
  - name: "订单金额非负"
    type: "range"
    min: 0
    severity: "error"  # 错误：不应一刀切都是 error
    
  - name: "用户昵称长度"
    type: "length"
    min: 1
    max: 50
    severity: "error"  # 错误：昵称不重要，不该是 error
    
  - name: "邮箱格式"
    type: "regex"
    pattern: "^[\w.-]+@[\w.-]+\.\w+$"
    severity: "error"  # 错误：邮箱允许为空，不该都是 error
```

✅ 正例：

```yaml
# 正确：按业务重要性分级
rules:
  # 高优先级（必须 100% 通过）
  - name: "订单金额非负"
    type: "range"
    min: 0
    severity: "error"
    priority: "P0"
    
  # 中优先级（允许 < 5% 异常）
  - name: "邮箱格式"
    type: "regex"
    pattern: "^[\w.-]+@[\w.-]+\.\w+$"
    severity: "warning"
    priority: "P1"
    tolerance: 0.05  # 允许 5% 异常
    
  # 低优先级（允许 < 10% 异常）
  - name: "用户昵称长度"
    type: "length"
    min: 1
    max: 50
    severity: "info"
    priority: "P2"
    tolerance: 0.10
```

💡 **为什么**：
- 一刀切导致告警噪音，重要问题被淹没
- 不同字段业务重要性不同，应有不同容忍度
- 合理的分级让团队聚焦真正重要的问题

---

### ❌ 反例 2：阈值过严

```yaml
# 错误：阈值设为 0，任何异常都告警
- name: "每日订单数波动"
  type: "range"
  min: 1000000
  max: 1000000  # 每天都必须正好 100 万
  severity: "error"
```

✅ 正例：

```yaml
# 正确：设置合理波动范围
- name: "每日订单数波动"
  type: "range"
  # 基于历史 P5-P95 设置
  min: 800000
  max: 1200000
  # 或者使用相对波动
  threshold_expression: |
    ABS(today_count - avg(last_7_days)) / avg(last_7_days) < 0.2
  severity: "warning"
```

💡 **为什么**：
- 真实业务数据每天都有波动（促销、节假日、季节性）
- 阈值过严导致大量误报，"狼来了"效应
- 应基于历史 P5-P95 或平均波动设置合理区间

---

### ❌ 反例 3：空值一刀切

```yaml
# 错误：要求所有字段都不能为空
rules:
  - name: "邮箱非空"
    not_null: true
    severity: "error"
```

✅ 正例：

```yaml
# 正确：根据业务判断空值合理性
rules:
  # 核心字段：必须非空
  - name: "订单ID非空"
    column: "order_id"
    not_null: true
    severity: "error"
    reason: "订单ID是主键，必填"
    
  # 业务字段：必填但允许缺失
  - name: "用户邮箱非空"
    column: "email"
    not_null: true
    severity: "warning"
    tolerance: 0.02  # 允许 2% 缺失
    reason: "部分用户未提供邮箱，常见现象"
    
  # 可选字段：不要求非空
  - name: "用户昵称"
    column: "nickname"
    not_null: false
    severity: "info"
    reason: "昵称是可选的"
    
  # 关联字段：业务上可空
  - name: "退款原因"
    column: "refund_reason"
    not_null: false
    severity: "info"
    reason: "未退款的订单无退款原因"
```

💡 **为什么**：
- 不同字段空值合理性不同
- 一刀切要求所有字段非空，会产生大量误报
- 应根据业务规则明确哪些字段是"必填但允许缺失" vs "可选"

---

### ❌ 反例 4：质量检查放在错误的位置

```python
# 错误：质量检查放在数据已经消费之后
def etl_pipeline():
    # 1. 同步数据
    sync_data_to_dwd()
    sync_data_to_dws()
    sync_data_to_ads()  # ADS 已生成，下游已消费
    
    # 2. 质量检查（已经晚了！）
    check_quality()  # ❌ 如果数据有问题，ADS 和下游都已消费
```

✅ 正例：

```python
# 正确：质量检查放在数据消费前
def etl_pipeline():
    # 1. 同步数据到 DWD
    sync_data_to_dwd()
    
    # 2. 在 DWD 阶段做质量检查（关键检查点）
    if not check_quality('dwd_orders'):
        logger.error("DWD 质量检查失败，阻断下游")
        return  # 阻断下游，防止问题数据扩散
    
    # 3. 同步到 DWS（只有通过检查的数据才往下走）
    sync_data_to_dws()
    
    # 4. DWS 也做检查
    if not check_quality('dws_trade_user_1d'):
        logger.error("DWS 质量检查失败")
        return
    
    # 5. 同步到 ADS
    sync_data_to_ads()
```

💡 **为什么**：
- 质量检查应该是"门禁"，不是"审计"
- 在数据消费前检查，能有效阻止问题数据扩散
- 越早发现越早修复，成本越低

---

### ❌ 反例 5：告警没分级

```yaml
# 错误：所有异常都发到钉钉群
- name: "订单状态枚举值"
  type: "enum"
  values: ["pending", "paid", "completed", "cancelled", "refunded"]
  severity: "error"  # 实际只有 0.1% 异常，也全量告警
  alert: "钉钉群"
```

✅ 正例：

```yaml
# 正确：告警分级
rules:
  # P0：核心业务异常，5 分钟内响应
  - name: "订单主键重复"
    severity: "critical"
    alert:
      channel: "钉钉 + 电话"
      response_sla: "5min"
      
  # P1：重要异常，30 分钟内响应
  - name: "订单状态枚举值异常"
    severity: "error"
    alert:
      channel: "钉钉"
      response_sla: "30min"
      
  # P2：一般异常，4 小时内响应
  - name: "用户邮箱格式异常"
    severity: "warning"
    alert:
      channel: "邮件 + 钉钉群（不 @ 个人）"
      response_sla: "4h"
      
  # P3：可观察但不告警
  - name: "订单金额分布偏离"
    severity: "info"
    alert:
      channel: "周报"
      response_sla: "次日"
```

💡 **为什么**：
- 所有异常都告警，导致告警疲劳
- 重要问题被噪音淹没
- 分级告警让团队聚焦真正紧急的问题

---

### ❌ 反例 6：检查脚本未与环境解耦

```sql
-- 错误：硬编码数据库名
SELECT COUNT(*) FROM adb_prod.dwd_orders WHERE pt = '2024-01-15';
```

✅ 正例：

```sql
-- 正确：使用变量
SELECT COUNT(*) FROM ${db_name}.dwd_orders WHERE pt = '${bizdate}';
```

```python
# 正确：脚本读取环境变量
import os
db_name = os.getenv('DQ_DB_NAME', 'dwd_layer')
check_query = f"SELECT COUNT(*) FROM {db_name}.dwd_orders WHERE pt = '{bizdate}'"
```

💡 **为什么**：
- 硬编码导致开发、测试、生产环境的检查脚本需要分别维护
- 使用变量可以一份脚本多环境复用
- 减少维护成本和出错的可能

---

## 3. 质量规则配置示例

### 3.1 完整的订单表质量规则集

```yaml
# orders_table_quality_rules.yaml
target_table: "dwd_trade_order_detail"
owner: "data-team@company.com"
last_updated: "2024-01-15"

rules:
  # ========== P0 规则（核心业务）==========
  - rule_id: "ORD_COMP_001"
    name: "订单主键非空"
    column: "order_id"
    type: "not_null"
    severity: "critical"
    threshold: 0
    alert:
      channel: "钉钉 + 电话"
      owner: "data-team"
      
  - rule_id: "ORD_UNIQ_001"
    name: "订单主键唯一"
    column: "order_id"
    type: "unique"
    severity: "critical"
    threshold: 0
    
  - rule_id: "ORD_COMP_002"
    name: "用户ID非空"
    column: "user_id"
    type: "not_null"
    severity: "critical"
    threshold: 0
    
  - rule_id: "ORD_VALID_001"
    name: "订单金额非负"
    column: "order_amount"
    type: "range"
    min: 0
    severity: "critical"
    threshold: 0
    
  # ========== P1 规则（重要）==========
  - rule_id: "ORD_VALID_002"
    name: "订单状态枚举值"
    column: "status"
    type: "enum"
    values: ["pending", "paid", "completed", "cancelled", "refunded"]
    severity: "error"
    threshold: 0.01  # 允许 1% 异常
    
  - rule_id: "ORD_VALID_003"
    name: "订单时间合理"
    column: "order_time"
    type: "range"
    min: "2020-01-01"
    max: "2030-12-31"
    severity: "error"
    threshold: 0
    
  # ========== P2 规则（一般）==========
  - rule_id: "ORD_VALID_004"
    name: "订单金额范围"
    column: "order_amount"
    type: "range"
    min: 0
    max: 1000000
    severity: "warning"
    threshold: 0.05  # 允许 5% 异常
```

### 3.2 质量评分计算 SQL

```sql
-- 综合质量评分（按维度）
WITH dimension_scores AS (
    SELECT
        check_date,
        dimension,
        -- 完整性：not_null 通过率
        AVG(CASE WHEN rule_type = 'not_null' THEN pass_rate END) AS completeness,
        -- 唯一性
        AVG(CASE WHEN rule_type = 'unique' THEN pass_rate END) AS uniqueness,
        -- 有效性：range、enum、regex
        AVG(CASE WHEN rule_type IN ('range', 'enum', 'regex') THEN pass_rate END) AS validity,
        -- 一致性：跨表对账
        AVG(CASE WHEN rule_type = 'consistency' THEN pass_rate END) AS consistency,
        -- 及时性：数据新鲜度
        AVG(CASE WHEN rule_type IN ('freshness', 'timeliness') THEN pass_rate END) AS timeliness,
        -- 准确性：业务规则校验
        AVG(CASE WHEN rule_type = 'accuracy' THEN pass_rate END) AS accuracy
    FROM dq_check_results
    WHERE check_date = CURRENT_DATE
    GROUP BY check_date, dimension
)
SELECT
    check_date,
    dimension,
    completeness,
    uniqueness,
    validity,
    consistency,
    timeliness,
    accuracy,
    -- 综合评分（6 维度加权，权重与 data-quality-standards.md 一致：
    -- 完整性25% + 唯一性20% + 有效性25% + 一致性15% + 及时性10% + 准确性5%）
    -- COALESCE 保证无规则的维度不破坏总分（视为满分 100）
    ROUND(
        COALESCE(completeness, 100) * 0.25 +
        COALESCE(uniqueness, 100) * 0.20 +
        COALESCE(validity, 100) * 0.25 +
        COALESCE(consistency, 100) * 0.15 +
        COALESCE(timeliness, 100) * 0.10 +
        COALESCE(accuracy, 100) * 0.05,
        2
    ) AS overall_score,
    -- 健康度评级
    CASE
        WHEN COALESCE(completeness,100)*0.25 + COALESCE(uniqueness,100)*0.20 + COALESCE(validity,100)*0.25 + COALESCE(consistency,100)*0.15 + COALESCE(timeliness,100)*0.10 + COALESCE(accuracy,100)*0.05 >= 99 THEN '🟢 优秀'
        WHEN COALESCE(completeness,100)*0.25 + COALESCE(uniqueness,100)*0.20 + COALESCE(validity,100)*0.25 + COALESCE(consistency,100)*0.15 + COALESCE(timeliness,100)*0.10 + COALESCE(accuracy,100)*0.05 >= 95 THEN '🟡 良好'
        WHEN COALESCE(completeness,100)*0.25 + COALESCE(uniqueness,100)*0.20 + COALESCE(validity,100)*0.25 + COALESCE(consistency,100)*0.15 + COALESCE(timeliness,100)*0.10 + COALESCE(accuracy,100)*0.05 >= 90 THEN '🟠 警告'
        ELSE '🔴 异常'
    END AS health_status
FROM dimension_scores;
```

## 4. 经验教训

### 踩坑 #1：空值率告警风暴

**场景**：上游源系统 bug 导致某天所有表的空值率飙升 10%，触发上千条告警，团队被淹没。
**原因**：所有规则独立告警，无聚合。
**解决**：在告警层做聚合，相同表 + 相同时间窗口的多个异常合并告警。
**预防**：告警聚合 + 静默期（如 30 分钟内相同问题不重复告警）。

### 踩坑 #2：质量规则无人维护，变成"僵尸规则"

**场景**：3 年前定义的质量规则还在跑，但业务字段早已废弃，规则永远报错。
**原因**：规则缺少 owner，废弃后无人清理。
**解决**：每月做一次规则审计，清理无效规则。
**预防**：每个规则必须配置 owner，规则审计纳入月度治理。

### 踩坑 #3：阈值过严导致 ETL 任务每天失败

**场景**：某核心表设置了 "每天 0 异常" 的质量规则，但每天都有 0.01% 异常（业务允许），导致 ETL 任务每天告警失败。
**原因**：阈值设置过于理想化，未考虑真实业务数据。
**解决**：将阈值从 0 调整为 0.01%（业务可接受范围）。
**预防**：阈值设置前先看历史数据的实际分布，不要拍脑袋。

### 踩坑 #4：质量检查在数据消费之后才发现问题

**场景**：某天 ADS 报表数据异常，业务方投诉后才检查发现 DWD 早就出问题。
**原因**：质量检查放在 DWD 同步之后，但没阻断下游。
**解决**：将 DWD 质量检查改为阻塞性检查，未通过则阻断 DWS 和 ADS 同步。
**预防**：建立"质量门禁"机制，问题数据不能往下一层流。

### 踩坑 #5：跨表一致性检查未做

**场景**：DWS 表的 GMV 与 ADS 报表的 GMV 对不上，但单表检查都通过。
**原因**：没做跨表对账检查。
**解决**：增加跨表一致性规则：`dws_trade.gmv = ads_sales_report.gmv`。
**预防**：每个聚合指标都应该有跨层对账检查。

## 5. 协作建议

### 5.1 与业务方协作

| 阶段 | 协作要点 |
|------|---------|
| 规则设计 | 与业务方确认字段含义、允许的空值范围、合理的异常值 |
| 阈值设置 | 基于历史数据分布 + 业务可接受范围 |
| 告警响应 | 重要告警应自动通知业务方，避免"业务方最后一个知道" |
| 异常处理 | 异常确认后应及时反馈业务方，形成闭环 |

### 5.2 与数据开发协作

| 协作点 | 建议 |
|--------|------|
| 规则嵌入 ETL | 质量检查应嵌入 ETL 流程，而非独立运行 |
| 失败处理 | ETL 任务失败应有明确处理（重试 / 告警 / 跳过） |
| 元数据维护 | 表结构变更时同步更新质量规则 |
| 规则评审 | 新增规则走评审流程，避免规则爆炸 |

### 5.3 质量团队建设建议

- **建立质量 Owner 制度**：每个表的规则有明确 owner
- **定期规则评审**：每月一次，清理无效规则
- **质量评分公示**：周报/月报公示各表质量评分
- **故障复盘机制**：重大质量问题做 RCA 并沉淀经验

---

**附录**：
- 详细规范：[data-quality-standards.md](data-quality-standards.md)
- 规则生成器：[dq-rule-gen.md](dq-rule-gen.md)
- 检查执行器：[dq-check.md](dq-check.md)
