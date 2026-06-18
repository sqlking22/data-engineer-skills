---
name: dw-refactor-assistant-best-practices
description: |
  数仓重构最佳实践 - 团队经验沉淀，包含重构优先级判定、双跑阈值设置、灰度切换策略、回滚触发条件。
  触发词：数仓重构、最佳实践、避坑指南、重构优先级、双跑、灰度切换、回滚、烟囱式开发。
---

# 数仓重构最佳实践

> 本文沉淀团队在数仓重构方面的实战经验，配套 [SKILL.md](../SKILL.md) 一起使用。
> 完整方法论见 [refactor-methodology.md](refactor-methodology.md)。

## 1. 核心原则速查

| # | 核心原则 | 说明 |
|---|---------|------|
| 1 | **先盘点后重构** | 没有资产清单和优先级，不要动手 |
| 2 | **业务连续性优先** | 重构不能影响下游报表和用户 |
| 3 | **渐进式迁移** | 一次性迁移风险太高，分批推进 |
| 4 | **双跑验证** | 新旧并行运行，数据一致后才能切 |
| 5 | **可回滚** | 每步操作都有回滚预案，触发条件明确 |
| 6 | **影响分析必做** | 任何变更前先评估下游影响 |
| 7 | **沟通到位** | 下游用户必须提前知晓变更时间 |
| 8 | **避免过度重构** | 只重构真正有问题的部分，不要全盘推翻 |

## 2. 反模式与避坑指南

### ❌ 反例 1：没做盘点就动手重构

```yaml
# 错误：直接基于"印象"开始重构
plan:
  - "听说订单表有重复，先合并"
  - "财务说 GMV 不对，重算"
  - "运营抱怨查询慢，优化 SQL"
# 问题：
# - 没有完整资产清单
# - 不知道重复表到底有几张
# - 不知道 GMV 不对的根本原因
# - 不知道查询慢的真实瓶颈
```

✅ 正例：

```yaml
# 正确：先盘点，建立基线
phase_1: 现状盘点（2 周）
  - 资产清单：1250 张表，850 GB
  - 问题清单：785 个（按 P0/P1/P2/P3 排序）
  - 优先矩阵：P0 15 个，P1 105 个
  - 影响地图：核心链路依赖图

phase_2: 制定计划（1 周）
  - 选定 P0 问题优先处理
  - 评估每个问题的迁移成本
  - 制定 4 周迁移计划
  - 准备回滚预案

phase_3: 实施迁移（4 周）
  - 按计划分批执行
  - 每批独立可回滚
  - 每批完成后验证
```

💡 **为什么**：
- 凭印象重构容易遗漏真正重要的问题
- 没有基线就无法评估效果
- 没有计划会导致边做边改，越改越乱

---

### ❌ 反例 2：一次性迁移所有表

```yaml
# 错误：一次性切换 30 张核心表
migration:
  date: "2024-02-01"
  tables: 30
  duration: "一次性切换"
  risk: "all_or_nothing"
  # 问题：如果失败，30 张表全部回滚
```

✅ 正例：

```yaml
# 正确：分批迁移，每批独立可回滚
migration:
  batches:
    - batch: 1
      date: "2024-02-01"
      tables: 5
      type: "内部任务（低风险）"
      rollback: "立即恢复"
      
    - batch: 2
      date: "2024-02-08"
      tables: 10
      type: "非核心报表（中风险）"
      rollback: "< 30 分钟"
      
    - batch: 3
      date: "2024-02-15"
      tables: 10
      type: "非核心报表（中风险）"
      rollback: "< 30 分钟"
      
    - batch: 4
      date: "2024-02-22"
      tables: 5
      type: "核心报表（高风险）"
      rollback: "< 1 小时"
```

💡 **为什么**：
- 一次性迁移风险太大
- 一旦失败影响范围广
- 分批后即使某批失败，其他批次不受影响

---

### ❌ 反例 3：双跑期追求 100% 一致

```yaml
# 错误：要求新旧模型数据 100% 一致
acceptance_criteria:
  data_consistency: 100%  # 几乎不可能达到
  # 实际：
  # - 时区差异（毫秒级）
  # - 浮点精度差异
  # - 并发更新导致的小波动
```

✅ 正例：

```yaml
# 正确：基于业务影响设置合理阈值
acceptance_criteria:
  # 主键：必须完全一致
  primary_key_match: 100%  # 主键是基础
  unique_violation: 0
  
  # 行数：允许极小波动
  row_count:
    diff_threshold: 0  # 整数精确匹配（订单数）
    # 或者允许 ±0.01% 差异（用户行为日志）
    diff_tolerance_rate: 0.0001
    
  # 金额：允许小数精度差异
  amount:
    diff_tolerance_abs: 0.01  # 绝对差异 < 0.01 元
    # 或者按比例
    diff_tolerance_rel: 0.0001  # 相对差异 < 0.01%
    
  # 状态枚举：必须完全一致
  enum_values_match: 100%
  
  # 时间戳：允许毫秒级差异
  timestamp:
    diff_tolerance_ms: 1000  # 1 秒内
```

💡 **为什么**：
- 100% 一致几乎不可能（时区、浮点、并发）
- 不合理的阈值会导致永远无法通过
- 应基于业务影响设置合理范围

---

### ❌ 反例 4：没做影响分析就改表名

```sql
-- 错误：直接重命名表
RENAME TABLE dwd_order_detail_1 TO dwd_trade_order_detail;
-- 下游 8 个任务直接报错！
```

✅ 正例：

```sql
-- 正确：先用视图兼容
-- 1. 创建新表
CREATE TABLE dwd_trade_order_detail (...);

-- 2. 用视图兼容旧表名
CREATE OR REPLACE VIEW dwd_order_detail_1 AS
SELECT * FROM dwd_trade_order_detail;

-- 3. 通知下游用户
-- 4. 给下游 2-4 周迁移时间
-- 5. 确认无下游使用后，删除视图
```

💡 **为什么**：
- 直接重命名会立即破坏所有下游
- 视图兼容提供平滑过渡
- 给下游留出迁移时间

---

### ❌ 反例 5：回滚预案不具体

```yaml
# 错误：模糊的"出问题就回滚"
rollback_plan: "如果迁移失败就回滚"
# 问题：
# - 什么算失败？
# - 怎么回滚？
# - 多久能恢复？
# - 谁负责？
```

✅ 正例：

```yaml
# 正确：明确的回滚预案
rollback_plan:
  triggers:
    - condition: "双跑期数据一致率 < 99.9%"
      action: "自动停止新模型任务"
    - condition: "下游任务失败率 > 5%"
      action: "30 分钟内回滚"
    - condition: "用户报告数据问题"
      action: "1 小时内回滚"
      
  steps:
    step_1:
      action: "停止新模型任务"
      command: "PAUSE task_dwd_trade_order_detail"
      time: "立即"
      
    step_2:
      action: "恢复旧模型任务"
      command: "RESUME task_dwd_order_detail_1"
      time: "< 5 分钟"
      
    step_3:
      action: "切换下游到旧表"
      command: "UPDATE task_config SET source = 'dwd_order_detail_1'"
      time: "< 15 分钟"
      
    step_4:
      action: "验证恢复"
      command: "RUN task_dws_trade_summary"
      time: "< 30 分钟"
      
  notification:
    - "钉钉群公告"
    - "邮件给下游用户"
    - "回滚 RCA 报告"
    
  owner: "data-team@company.com"
```

💡 **为什么**：
- 没有明确的触发条件，团队无法决策何时回滚
- 没有具体步骤，回滚会手忙脚乱
- 没有负责人，可能无人处理

---

### ❌ 反例 6：一次合并太多表

```sql
-- 错误：一次性合并 5 个重复表
MERGE TABLE dwd_order_detail_1, dwd_order_detail_2, dwd_order_detail_3,
        dwd_order_detail_4, dwd_order_detail_5
INTO dwd_trade_order_detail;
-- 问题：
-- - 数据差异大，无法定位问题
-- - 下游多，一次切换风险大
-- - 冲突解决困难
```

✅ 正例：

```sql
-- 正确：分阶段合并，每个表独立处理
-- 阶段 1：合并 1+2
--   - 分析差异
--   - 保留口径正确的
--   - 标记另一个为废弃
--   - 合并到新表

-- 阶段 2：合并 3
--   - 重新分析
--   - 验证与阶段 1 一致
--   - 合并

-- 阶段 3：合并 4+5
--   - 最后处理
--   - 需要更多业务确认
```

💡 **为什么**：
- 一次合并太多表，无法定位问题
- 数据差异大时风险高
- 分阶段可以逐步验证

---

## 3. 实操示例

### 3.1 重构优先级判定公式

```python
def calculate_refactor_priority(issue):
    """
    重构优先级判定
    
    公式: 优先级 = 影响范围 × 维护成本 / 迁移风险
    """
    # 1. 影响范围（0-10）
    impact_score = 0
    if issue.affects_core_reports:
        impact_score += 5
    if issue.affects_users > 50:
        impact_score += 3
    if issue.causes_data_inconsistency:
        impact_score += 2
    
    # 2. 维护成本（0-10）
    maintenance_cost = 0
    if issue.duplicate_count > 1:
        maintenance_cost += 3 * issue.duplicate_count
    if issue.storage_waste_gb > 10:
        maintenance_cost += 2
    if issue.developer_count > 1:
        maintenance_cost += 2  # 多人维护成本高
    if issue.changes_frequently:
        maintenance_cost += 2
    
    # 3. 迁移风险（0-10）
    migration_risk = 0
    if issue.has_complex_logic:
        migration_risk += 4
    if issue.touches_critical_path:
        migration_risk += 3
    if issue.has_unclear_business:
        migration_risk += 3
    
    # 计算优先级
    priority_score = (impact_score * maintenance_cost) / max(migration_risk, 1)
    
    if priority_score >= 15:
        return 'P0'  # 立即处理
    elif priority_score >= 10:
        return 'P1'  # 1-2 周
    elif priority_score >= 5:
        return 'P2'  # 1-2 月
    else:
        return 'P3'  # 长期

# 使用示例
issue = {
    'affects_core_reports': True,
    'affects_users': 100,
    'causes_data_inconsistency': True,
    'duplicate_count': 3,
    'storage_waste_gb': 50,
    'developer_count': 2,
    'changes_frequently': True,
    'has_complex_logic': True,
    'touches_critical_path': True,
    'has_unclear_business': False
}
print(calculate_refactor_priority(issue))  # P0
```

### 3.2 双跑数据对比 SQL

```sql
-- 双跑数据对比（以订单金额为例）
WITH old_data AS (
    SELECT
        order_id,
        user_id,
        amount,
        status,
        pt
    FROM dwd_order_detail_1
    WHERE pt BETWEEN '20240101' AND '20240131'
),
new_data AS (
    SELECT
        order_id,
        user_id,
        amount,
        status,
        pt
    FROM dwd_trade_order_detail
    WHERE pt BETWEEN '20240101' AND '20240131'
),
comparison AS (
    SELECT
        COALESCE(o.order_id, n.order_id) AS order_id,
        o.amount AS old_amount,
        n.amount AS new_amount,
        o.status AS old_status,
        n.status AS new_status,
        -- 计算差异
        CASE WHEN o.order_id IS NULL THEN 'MISSING_IN_OLD'
             WHEN n.order_id IS NULL THEN 'MISSING_IN_NEW'
             ELSE 'BOTH_EXIST'
        END AS existence
    FROM old_data o
    FULL OUTER JOIN new_data n ON o.order_id = n.order_id
)
SELECT
    '行数对比' AS check_item,
    COUNT(*) FILTER (WHERE existence = 'BOTH_EXIST') AS matched_count,
    COUNT(*) FILTER (WHERE existence = 'MISSING_IN_OLD') AS missing_in_new,
    COUNT(*) FILTER (WHERE existence = 'MISSING_IN_NEW') AS missing_in_old
FROM comparison

UNION ALL

SELECT
    '金额对比' AS check_item,
    SUM(CASE WHEN existence = 'BOTH_EXIST' AND ABS(old_amount - new_amount) < 0.01 THEN 1 ELSE 0 END) AS exact_match,
    SUM(CASE WHEN existence = 'BOTH_EXIST' AND ABS(old_amount - new_amount) >= 0.01 THEN 1 ELSE 0 END) AS amount_mismatch,
    0 AS missing_in_old
FROM comparison

UNION ALL

SELECT
    '状态对比' AS check_item,
    SUM(CASE WHEN existence = 'BOTH_EXIST' AND old_status = new_status THEN 1 ELSE 0 END) AS status_match,
    SUM(CASE WHEN existence = 'BOTH_EXIST' AND old_status != new_status THEN 1 ELSE 0 END) AS status_mismatch,
    0 AS missing_in_old
FROM comparison;
```

### 3.3 灰度切换方案

```yaml
# 灰度切换（按用户分批）
gray_release:
  - phase: 1
    name: "内部用户灰度"
    traffic: 5%        # 5% 流量
    criteria: "公司内部用户（user_id IN 内网 ID 段）"
    duration: "3 天"
    success_criteria:
      - "内部用户无问题反馈"
      - "数据一致率 > 99.9%"
      
  - phase: 2
    name: "小流量用户"
    traffic: 20%        # 20% 流量
    criteria: "随机 20% 用户"
    duration: "3 天"
    success_criteria:
      - "问题反馈率 < 0.1%"
      - "性能无明显下降"
      
  - phase: 3
    name: "全量用户"
    traffic: 100%        # 100% 流量
    duration: "持续"
    success_criteria: "无重大问题"
```

### 3.4 重构进度看板

```yaml
# refactor_dashboard.yaml
refactor_project: "交易域模型重构"
start_date: "2024-02-01"
target_date: "2024-03-01"

milestones:
  - milestone: "P0 问题修复"
    target: "2024-02-07"
    status: "in_progress"
    progress: 0.6
    items:
      - "跨层依赖修复: done"
      - "循环依赖修复: in_progress"
      - "核心链路表重复合并: pending"
      
  - milestone: "P1 问题修复"
    target: "2024-02-15"
    status: "pending"
    progress: 0
    
  - milestone: "全量验证"
    target: "2024-02-22"
    status: "pending"
    progress: 0

risks:
  - risk: "下游用户对变更的接受度"
    level: "中"
    mitigation: "提前 1 周通知 + 灰度切换"
    
  - risk: "数据一致性问题"
    level: "高"
    mitigation: "双跑 2 周 + 严格阈值"
```

## 4. 经验教训

### 踩坑 #1：低估了数据迁移的复杂性

**场景**：以为是简单的"表重命名"，实际涉及下游 12 个任务、5 个报表、3 个 ETL 流程。
**原因**：未做影响分析就动手。
**解决**：回滚到旧表，按计划重新开始。
**预防**：任何变更前必做影响分析，预留 2x 计划时间。

### 踩坑 #2：双跑期出现"幽灵数据差异"

**场景**：新旧模型数据始终有 0.001% 差异，查了 2 天没找到原因。
**原因**：旧表有个未文档化的"补丁任务"，每天运行后修正部分数据。
**解决**：识别并停用补丁任务，或者在新模型中复现补丁逻辑。
**预防**：盘点阶段要识别所有"未文档化"的任务和补丁。

### 踩坑 #3：回滚后部分下游未完全恢复

**场景**：回滚后部分报表数据未恢复，因为视图层缓存。
**原因**：回滚步骤不完整，只切了任务层，没切视图层。
**解决**：重新审视所有可能的缓存层（任务、视图、BI 报表缓存）。
**预防**：回滚清单要完整覆盖：任务、视图、缓存、用户权限。

### 踩坑 #4：迁移后命名规范执行不彻底

**场景**：花了 2 个月迁移，但 6 个月后又有 50 张新表命名不规范。
**原因**：没有建立"命名规范自动化检查"，依赖人工审查。
**解决**：在 ETL 上线流程中加入命名规范检查，违规表无法上线。
**预防**：将规范检查自动化，作为上线卡点。

### 踩坑 #5：忽略业务方对"旧名字"的依赖

**场景**：表名改了，但业务方在 BI 工具中硬编码了旧表名，报表全部报错。
**原因**：未通知业务方，未提供兼容性视图。
**解决**：回滚 + 提供视图兼容。
**预防**：表名变更要通知所有相关方 + 提供至少 1 季度的视图兼容期。

## 5. 协作建议

### 5.1 与业务方协作

| 阶段 | 协作要点 |
|------|---------|
| 重构规划 | 提前 1 个月通知业务方变更计划 |
| 双跑期 | 邀请业务方对比新旧数据，签字确认 |
| 切换期 | 提供 1-2 周的灰度切换，业务方可选择性回退 |
| 完成后 | 收集反馈，迭代优化 |

### 5.2 与下游用户协作

| 协作点 | 建议 |
|--------|------|
| 变更通知 | 提前 2 周邮件 + 钉钉通知所有下游 |
| 影响范围 | 明确告知哪些任务/报表受影响 |
| 切换时间 | 选择业务低峰期（如周末凌晨） |
| 回滚通道 | 任何时候可回滚，无需走审批 |
| 反馈渠道 | 设立专门的反馈群 / 邮件组 |

### 5.3 与团队内部协作

| 角色 | 协作建议 |
|------|---------|
| 数据架构师 | 主导方案设计，把关技术决策 |
| 开发工程师 | 实施迁移，承担测试和上线 |
| 测试工程师 | 制定双跑验证标准，验证一致性 |
| DBA | 性能优化，DDL 评审 |
| 运维 | 调度配置，监控告警 |

### 5.4 重构成功标准（参考指标）

| 类别 | 指标 | 当前 | 目标 |
|------|------|------|------|
| 结构 | 模型重复率 | 15% | < 2% |
| 结构 | 未归域表比例 | 25% | < 5% |
| 结构 | 跨层依赖数 | 35 | 0 |
| 效率 | 存储 | 850 GB | -30% |
| 效率 | 任务平均深度 | 12 | < 6 |
| 效率 | 新建需求交付 | 5 天 | < 2 天 |
| 质量 | 数据一致率 | 95% | > 99.9% |
| 治理 | 文档覆盖率 | 40% | > 90% |
| 治理 | 责任人覆盖率 | 70% | 100% |

---

**附录**：
- 完整方法论：[refactor-methodology.md](refactor-methodology.md)
- 资产盘点模板：[asset-inventory-template.md](asset-inventory-template.md)
- 血缘分析指南：[lineage-analysis-guide.md](lineage-analysis-guide.md)
- 迁移操作手册：[migration-playbook.md](migration-playbook.md)
- 治理框架：[governance-framework.md](governance-framework.md)
