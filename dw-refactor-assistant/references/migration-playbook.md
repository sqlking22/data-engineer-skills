---
name: migration-playbook
description: |
  数仓迁移操作手册 - 渐进式迁移的具体执行步骤和回滚预案。
  触发词：迁移手册、迁移步骤、回滚预案、双跑验证。
---

# 数仓迁移操作手册

## 1. 迁移策略选择

### 1.1 策略对比

| 策略 | 适用场景 | 优点 | 缺点 |
|------|---------|------|------|
| **一次性迁移** | 小规模（< 50表）、低风险 | 简单快速 | 风险高、难回滚 |
| **渐进式迁移** | 大规模、高风险 | 风险低、可回滚 | 周期长、资源消耗高 |
| **并行建设后切换** | 新建数仓 | 不影响旧系统 | 双倍资源 |
| **视图兼容过渡** | 有下游依赖 | 兼容性好 | 维护复杂 |

**推荐**：大规模数仓重构采用 **渐进式迁移 + 视图兼容过渡**。

---

## 2. 迁移阶段详解

### 阶段1：新模型建设（1-2周）

#### 1.1 设计新模型

```yaml
# 设计检查清单
design_checklist:
  
  # 表结构设计
  table_design:
    - [ ] 表名符合 {layer}_{domain}_{entity} 规范
    - [ ] 字段名符合 snake_case 规范
    - [ ] 主键定义正确
    - [ ] 分区策略合理
    - [ ] 分布键选择正确（ADB）
    
  # 字段设计
  field_design:
    - [ ] 字段类型正确
    - [ ] 字段注释完整
    - [ ] 默认值合理
    - [ ] 空值处理明确
    
  # 约束设计
  constraint_design:
    - [ ] 主键约束（ADB 需含分布键与分区键）
    - [ ] 外键约束（可选）
    - [ ] 检查约束
```

> **交叉引用**：分层规范（ODS/DWD/DWS/ADS/DIM）、数据域划分、事实表/维度表设计、SCD 策略、各层 DDL 模板，详见 **modeling-assistant**：
> - `modeling-assistant/references/onedata-methodology.md`（OneData：数据域、总线矩阵、原子/派生/衍生指标体系）
> - `modeling-assistant/references/data-modeling-standards.md`（Kimball：星型模型、事实表/维度表、代理键）
> - `modeling-assistant/references/model-design.md`（模型设计模板）
>
> **MaxCompute vs ADB MySQL 方言差异、DDL 语法、ETL INSERT 模板**，详见 **sql-assistant**：
> - `sql-assistant/references/adb-mysql-guide.md` 与 `sql-assistant/references/maxcompute-guide.md`（方言对照）
> - `sql-assistant/references/sql-standards.md`（命名、函数、分布键/分区/LIFECYCLE 写法）
>
> 本手册不再重复教授建模与 SQL，聚焦 **dw-refactor 专属**：迁移策略、阶段划分、双跑验证、视图兼容、下游切换、回滚。

---

### 阶段2：双跑验证（1周）

#### 2.1 双跑配置

```yaml
# dual_run_config.yaml
dual_run:
  old_model:
    table: "dwd_order_detail_1"
    task: "task_dwd_order_detail_1"
    
  new_model:
    table: "dwd_trade_order_detail"
    task: "task_dwd_trade_order_detail"
    
  # 双跑周期
  duration: "7 days"  # 双跑天数
  
  # 对比维度
  comparison:
    - dimension: "row_count"
      tolerance: 0  # 行数必须完全一致
      
    - dimension: "total_amount"
      tolerance: 0.0001  # 金额差异 < 0.01%
      
    - dimension: "unique_keys"
      tolerance: 0  # 主键必须完全一致
      
    - dimension: "field_distribution"
      sample_fields: ["status", "channel", "region"]
```

#### 2.2 数据对比脚本

```sql
-- 行数对比
SELECT 
    'old' AS model,
    COUNT(*) AS row_count
FROM dwd_order_detail_1
WHERE pt BETWEEN '${start_date}' AND '${end_date}'

UNION ALL

SELECT 
    'new' AS model,
    COUNT(*) AS row_count
FROM dwd_trade_order_detail
WHERE pt BETWEEN '${start_date}' AND '${end_date}';

-- 金额对比
SELECT 
    'old' AS model,
    SUM(total_amount) AS total_amount,
    COUNT(DISTINCT order_id) AS order_count
FROM dwd_order_detail_1
WHERE pt BETWEEN '${start_date}' AND '${end_date}'

UNION ALL

SELECT 
    'new' AS model,
    SUM(total_amount) AS total_amount,
    COUNT(DISTINCT order_id) AS order_count
FROM dwd_trade_order_detail
WHERE pt BETWEEN '${start_date}' AND '${end_date}';

-- 主键一致性对比
SELECT 
    'missing_in_new' AS issue,
    COUNT(*) AS count
FROM (
    SELECT order_id FROM dwd_order_detail_1 WHERE pt = '${bizdate}'
    EXCEPT
    SELECT order_id FROM dwd_trade_order_detail WHERE pt = '${bizdate}'
) t

UNION ALL

SELECT 
    'extra_in_new' AS issue,
    COUNT(*) AS count
FROM (
    SELECT order_id FROM dwd_trade_order_detail WHERE pt = '${bizdate}'
    EXCEPT
    SELECT order_id FROM dwd_order_detail_1 WHERE pt = '${bizdate}'
) t;

-- 字段值分布对比
SELECT 
    status,
    COUNT(*) AS cnt
FROM dwd_order_detail_1
WHERE pt = '${bizdate}'
GROUP BY status
ORDER BY status;

SELECT 
    status,
    COUNT(*) AS cnt
FROM dwd_trade_order_detail
WHERE pt = '${bizdate}'
GROUP BY status
ORDER BY status;
```

#### 2.3 双跑验收标准

```yaml
acceptance_criteria:
  
  # 数据一致性
  data_consistency:
    row_count_diff: 0           # 行数差异为 0
    amount_diff_rate: "< 0.01%" # 金额差异率 < 0.01%
    key_match_rate: 100%        # 主键匹配率 100%
    
  # 性能要求
  performance:
    duration_ratio: "< 1.2"     # 新模型时长不超过旧模型 1.2 倍
    resource_usage: "< 1.2"     # 资源消耗不超过 1.2 倍
    
  # 质量要求
  quality:
    null_rate: "< 1%"           # 空值率 < 1%
    duplicate_rate: 0           # 重复率 0
```

---

### 阶段3：视图兼容（1-2天）

#### 3.1 创建兼容视图

```sql
-- 创建与旧表同名的视图，指向新表
CREATE OR REPLACE VIEW dwd_order_detail_1 AS
SELECT 
    -- 保持旧字段名（如有差异需映射）
    order_item_sk,
    date_key,
    user_sk,
    product_sk,
    order_id,
    quantity,
    unit_price,
    discount_amount,
    total_amount,
    pt
FROM dwd_trade_order_detail;

-- 如果字段名有差异，需要别名映射
CREATE OR REPLACE VIEW dwd_order_detail_1 AS
SELECT 
    order_item_sk,
    date_key,
    user_sk,
    product_sk,
    order_id,
    quantity,
    unit_price,
    discount_amount,
    total_amount AS amount,  -- 旧字段名
    pt
FROM dwd_trade_order_detail;
```

#### 3.2 验证兼容性

```sql
-- 验证视图返回结果与旧表一致
SELECT COUNT(*) FROM dwd_order_detail_1 WHERE pt = '${bizdate}';
SELECT COUNT(*) FROM dwd_trade_order_detail WHERE pt = '${bizdate}';

-- 验证下游任务能否正常使用视图
-- 运行下游任务的测试版本
```

---

### 阶段4：下游切换（1周）

#### 4.1 切换顺序

```yaml
# 切换顺序（按风险从低到高）
switch_order:
  
  # 第一批：内部任务（低风险）
  batch_1:
    - task: "task_dws_trade_internal"
      reason: "内部使用，无外部依赖"
      
  # 第二批：非核心报表（中风险）
  batch_2:
    - task: "task_ads_order_analysis"
      reason: "非核心报表，用户少"
      
  # 第三批：核心报表（高风险）
  batch_3:
    - task: "task_ads_sales_report"
      reason: "核心报表，需要重点监控"
```

#### 4.2 切换操作

```yaml
# 单个任务切换步骤
switch_steps:
  
  Step 1: 备份当前配置
    action: "记录当前任务配置和SQL"
    
  Step 2: 修改源表引用
    action: |
      - 将 SQL 中的旧表名改为新表名
      - 或依赖视图兼容，不做修改
      
  Step 3: 测试运行
    action: "运行任务测试实例"
    
  Step 4: 验证结果
    action: |
      - 检查任务是否成功
      - 检查数据量是否正常
      - 检查数据质量
      
  Step 5: 监控告警
    action: "配置切换后的监控告警"
```

#### 4.3 监控配置

```yaml
# 切换后监控
post_switch_monitoring:
  
  # 数据监控
  data_checks:
    - name: "行数波动监控"
      check: "ABS(row_count - prev_count) / prev_count < 0.1"
      alert: "钉钉通知"
      
    - name: "数据新鲜度监控"
      check: "last_update < NOW() - INTERVAL 1 DAY"
      alert: "邮件通知"
      
  # 任务监控
  task_checks:
    - name: "任务成功率监控"
      check: "success_rate > 0.95"
      alert: "钉钉通知"
      
    - name: "运行时长监控"
      check: "duration < baseline * 1.5"
      alert: "钉钉通知"
```

---

### 阶段5：旧模型下线（1周）

#### 5.1 下线前检查

```yaml
# 下线检查清单
offline_checklist:
  
  # 依赖检查
  dependency_check:
    - [ ] 确认无下游任务直接依赖旧表
    - [ ] 确认视图兼容有效
    - [ ] 确认无用户直接查询旧表
    
  # 数据检查
  data_check:
    - [ ] 确认新模型数据完整
    - [ ] 确认历史数据已迁移
    - [ ] 确认无数据质量问题
    
  # 文档检查
  documentation_check:
    - [ ] 更新资产清单
    - [ ] 更新血缘图谱
    - [ ] 更新用户文档
```

#### 5.2 下线步骤

```yaml
offline_steps:
  
  Step 1: 停止旧任务
    action: "PAUSE task_dwd_order_detail_1"
    keep_backup: true
    backup_duration: "30 days"
    
  Step 2: 归档旧表数据
    action: |
      - 导出旧表数据到备份存储
      - 保留最近 30 天数据
      
  Step 3: 删除旧表（可选）
    action: "DROP TABLE dwd_order_detail_1"
    condition: "确认无任何依赖后执行"
    alternative: "重命名为 dwd_order_detail_1_deprecated"
    
  Step 4: 清理视图
    action: "DROP VIEW dwd_order_detail_1"
    condition: "所有下游已切换到新表后执行"
    
  Step 5: 更新文档
    action: |
      - 更新资产清单，标记旧表已下线
      - 更新血缘图谱
      - 通知相关用户
```

---

## 3. 回滚预案

### 3.1 回滚触发条件

```yaml
rollback_triggers:
  
  # 自动触发
  automatic:
    - condition: "双跑数据一致率 < 99.9%"
      action: "自动停止新模型任务"
      
    - condition: "下游任务失败率 > 5%"
      action: "自动回滚到旧模型"
      
  # 手动触发
  manual:
    - condition: "用户报告数据问题"
      approval: "数据负责人确认"
      
    - condition: "发现重大逻辑错误"
      approval: "技术负责人确认"
```

### 3.2 回滚操作步骤

```yaml
rollback_procedure:
  
  Step 1: 停止新模型任务
    commands:
      - "PAUSE task_dwd_trade_order_detail"
      - "PAUSE task_dws_trade_summary_new"
    expected_time: "立即"
    
  Step 2: 恢复旧模型任务
    commands:
      - "RESUME task_dwd_order_detail_1"
      - "RESUME task_dws_trade_summary"
    expected_time: "< 5 分钟"
    
  Step 3: 切换下游任务
    commands:
      - "UPDATE task_config SET source_table = 'dwd_order_detail_1'"
      - "或删除视图，恢复旧表"
    expected_time: "< 15 分钟"
    
  Step 4: 验证恢复
    commands:
      - "RUN task_dws_trade_summary"
      - "CHECK downstream_reports"
    expected_time: "< 30 分钟"
    
  Step 5: 通知用户
    actions:
      - "发布回滚公告"
      - "说明回滚原因"
      - "提供后续计划"
```

### 3.3 回滚脚本

```bash
#!/bin/bash
# rollback.sh - 回滚脚本

OLD_TABLE="dwd_order_detail_1"
NEW_TABLE="dwd_trade_order_detail"
TASK_PREFIX="task"

echo "=== 开始回滚 ==="
echo "时间: $(date)"

# Step 1: 停止新任务
echo "Step 1: 停止新模型任务..."
pause_task "${TASK_PREFIX}_${NEW_TABLE}"

# Step 2: 恢复旧任务
echo "Step 2: 恢复旧模型任务..."
resume_task "${TASK_PREFIX}_${OLD_TABLE}"

# Step 3: 切换下游
echo "Step 3: 切换下游任务..."
for task in $(get_downstream_tasks "${NEW_TABLE}"); do
    update_task_source "${task}" "${OLD_TABLE}"
done

# Step 4: 验证
echo "Step 4: 验证恢复..."
run_task "${TASK_PREFIX}_dws_trade_summary"
check_result=$?

if [ $check_result -eq 0 ]; then
    echo "回滚成功！"
    notify_users "回滚完成，业务已恢复"
else
    echo "回滚验证失败，需要人工介入！"
    notify_users "回滚验证失败，请检查"
fi

echo "=== 回滚结束 ==="
```

---

## 4. 迁移检查清单

```markdown
## 迁移检查清单

### 迁移前
- [ ] 完成影响分析
- [ ] 获得变更审批
- [ ] 准备回滚预案
- [ ] 通知下游用户

### 迁移中
- [ ] 新模型建设完成
- [ ] 单元测试通过
- [ ] 双跑验证通过
- [ ] 视图兼容有效

### 迁移后
- [ ] 下游切换完成
- [ ] 数据验证通过
- [ ] 监控告警配置
- [ ] 文档更新完成

### 下线前
- [ ] 确认无依赖
- [ ] 数据已备份
- [ ] 用户已通知
- [ ] 文档已更新
```
