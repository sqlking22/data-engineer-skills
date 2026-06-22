---
name: governance-framework
description: |
  数仓治理框架 - 建立长效机制防止再次烟囱化。
  触发词：治理框架、数据治理、变更管控、复用机制。
---

# 数仓治理框架

## 1. 治理目标

```
治理三大目标:
  
  1. 规范化
     ─────────────────────────────────────
     目标: 统一标准，避免随意建设
     实现: 命名规范、分层规范、指标字典
     
  2. 可追溯
     ─────────────────────────────────────
     目标: 血缘清晰，责任明确
     实现: 血缘图谱、负责人制度、变更记录
     
  3. 可复用
     ─────────────────────────────────────
     目标: 公共沉淀，避免重复
     实现: 公共模型库、指标字典、复用流程
```

---

## 2. 组织保障

### 2.1 角色定义

```yaml
roles:
  
  # 决策层
  decision_level:
    - role: "数据架构师"
      count: "1-2 人"
      responsibility:
        - "模型设计评审"
        - "架构决策"
        - "规范制定"
        - "技术选型"
      required_skills:
        - "数仓建模经验 5+ 年"
        - "OneData/Kimball 方法论"
        - "阿里云数据库经验"
        
  # 执行层
  execution_level:
    - role: "数据开发工程师"
      count: "按域分配"
      responsibility:
        - "模型开发"
        - "ETL维护"
        - "数据质量"
      domain_assignment:
        - "交易域: 2 人"
        - "用户域: 1 人"
        - "流量域: 1 人"
        
    - role: "数据治理专员"
      count: "1 人"
      responsibility:
        - "规范检查"
        - "问题跟进"
        - "资产管理"
        - "定期审计"
        
  # 业务层
  business_level:
    - role: "数据产品经理"
      responsibility:
        - "需求管理"
        - "用户沟通"
        - "验收确认"
        
    - role: "业务域负责人"
      responsibility:
        - "业务需求确认"
        - "数据口径确认"
        - "验收签字"
```

### 2.2 评审委员会

```yaml
committees:
  
  - name: "数据架构评审委员会"
    members:
      - "数据架构师（主席）"
      - "技术负责人"
      - "各数据域负责人"
      - "数据治理专员"
      
    meeting_frequency: "每周二 10:00"
    
    review_scope:
      - "新建表申请"
      - "核心模型变更"
      - "跨域依赖"
      - "架构决策"
      
    decision_process:
      - "提交评审材料"
      - "架构师初审"
      - "委员会讨论"
      - "投票表决（2/3 以上通过）"
      - "记录决议"
      
  - name: "变更审批委员会"
    members:
      - "域负责人"
      - "数据架构师"
      - "下游用户代表"
      
    approval_levels:
      P0: ["架构评审委员会 + 业务负责人"]
      P1: ["架构师 + 域负责人"]
      P2: ["域负责人"]
      P3: ["开发者"]
```

---

## 3. 流程保障

### 3.1 模型设计流程

```yaml
model_design_process:
  
  # 新建模型
  new_model:
    steps:
      - name: "需求分析"
        executor: "数据产品经理"
        output: "需求文档"
        
      - name: "复用检查"
        executor: "数据治理专员"
        action: "检查公共模型库是否可复用"
        output: "复用评估报告"
        
      - name: "模型设计"
        executor: "数据开发工程师"
        input: "需求文档 + 复用评估"
        output: "模型设计文档"
        
      - name: "设计评审"
        executor: "数据架构师"
        action: "评审模型设计"
        criteria:
          - "命名规范"
          - "分层正确"
          - "粒度明确"
          - "维度完整"
          
      - name: "开发实施"
        executor: "数据开发工程师"
        action: "开发 DDL + ETL"
        
      - name: "测试验证"
        executor: "数据开发工程师"
        action: "单元测试 + 数据验证"
        
      - name: "上线发布"
        executor: "域负责人"
        action: "审批上线"
        
      - name: "纳入治理"
        executor: "数据治理专员"
        action: "更新资产清单 + 血缘图谱"
```

### 3.2 变更管控流程

```yaml
change_control_process:
  
  # 变更申请
  change_request:
    required_fields:
      - "变更类型（新增/修改/删除）"
      - "变更对象（表/字段/任务）"
      - "变更原因"
      - "影响分析报告"
      - "风险评估"
      - "回滚预案"
      
  # 变更分级
  change_levels:
    P0_critical:
      examples:
        - "删除核心事实表"
        - "修改核心指标口径"
        - "变更核心维度定义"
      approval: "架构评审委员会 + 业务负责人"
      review_time: "3-5 天"
      
    P1_major:
      examples:
        - "新增派生指标"
        - "修改 DWS 层表"
        - "新增数据域"
      approval: "数据架构师 + 域负责人"
      review_time: "1-2 天"
      
    P2_minor:
      examples:
        - "新增非核心字段"
        - "修改非核心任务"
        - "优化 SQL 性能"
      approval: "域负责人"
      review_time: "< 1 天"
      
    P3_routine:
      examples:
        - "添加字段注释"
        - "修改任务描述"
        - "调整调度时间"
      approval: "开发者自审"
      review_time: "立即"
      
  # 变更执行
  change_execution:
    steps:
      - "审批通过后执行"
      - "按迁移手册步骤执行"
      - "变更后验证"
      - "更新文档"
      - "通知下游"
```

### 3.3 复用流程

```yaml
reuse_process:
  
  # 复用检查流程
  reuse_check:
    trigger: "新建模型需求"
    steps:
      - name: "检查公共模型库"
        action: "搜索是否有相似模型"
        
      - name: "检查指标字典"
        action: "搜索是否有相同指标定义"
        
      - name: "检查维度字典"
        action: "搜索是否有相同维度"
        
      - name: "复用评估"
        action: "评估是否可以复用"
        
      - name: "不复用说明"
        condition: "如果决定新建"
        action: "必须说明不复用原因"
        
  # 公共模型申请流程
  public_model_request:
    trigger: "需要使用公共模型"
    steps:
      - name: "提交申请"
        content: "说明使用场景"
        
      - name: "审批"
        approver: "公共模型负责人"
        
      - name: "获取权限"
        action: "授予访问权限"
        
      - name: "使用"
        action: "在任务中引用公共模型"
```

---

## 4. 规范自动化检查

> **职责边界**：本节聚焦**结构/规范类**自动化检查（命名、分层、孤儿表、跨层/循环依赖），这些是 dw-refactor 治理专属。
> **数据质量类检查**（任务失败率、数据新鲜度、空值率、唯一性、一致性等规则定义、SQL 实现与告警配置）属于 dq-assistant 职责，详见 `dq-assistant/references/data-quality-standards.md`。治理流程触发 dq 规则，但不在此重新定义。

### 4.1 每日检查

```yaml
daily_checks:
  # 数据质量类检查（任务失败率、数据新鲜度、空值率等）
  # 规则定义、SQL 实现与告警配置详见 dq-assistant/references/data-quality-standards.md
  # 治理层仅订阅 dq 告警结果，纳入月度治理报告
  dq_subscription:
    schedule: "每天 09:00"
    source: "dq-assistant"
    action: "订阅告警，汇总至治理月报"
```

### 4.2 每周检查

```yaml
weekly_checks:
  
  # 周一执行
  monday_checks:
    schedule: "每周一 10:00"
    checks:
      - name: "命名规范检查"
        sql: |
          SELECT table_name FROM information_schema.tables
          WHERE table_name NOT REGEXP '^(ods|dwd|dws|ads|dim)_'
        threshold: "新增违规表 = 0"
        report: "生成违规清单"
        
      - name: "孤儿表检查"
        sql: |
          SELECT t.table_name 
          FROM information_schema.tables t
          WHERE NOT EXISTS (
            SELECT 1 FROM lineage_graph 
            WHERE downstream_table = t.table_name
          )
        threshold: "新增孤儿表 = 0"
        report: "生成清理清单"
        
  # 周三执行
  wednesday_checks:
    schedule: "每周三 10:00"
    checks:
      - name: "跨层依赖检查"
        sql: |
          SELECT source_table, target_table
          FROM lineage_graph
          WHERE 
            (target_table LIKE 'ads_%' AND source_table LIKE 'ods_%')
            OR (target_table LIKE 'ads_%' AND source_table LIKE 'dwd_%')
        threshold: "违规依赖 = 0"
        report: "生成违规清单"
        
      - name: "循环依赖检查"
        sql: |
          -- 检查是否存在循环依赖
          ...
        threshold: "循环依赖 = 0"
        alert: "立即通知架构师"
```

### 4.3 每月审计

```yaml
monthly_audit:
  
  schedule: "每月 1 日"
  
  scope:
    - "资产盘点更新"
    - "规范执行检查"
    - "问题整改跟踪"
    - "治理报告编写"
    
  audit_items:
  
    # 资产盘点
    asset_inventory:
      - "表数量统计"
      - "存储统计"
      - "负责人覆盖率"
      - "文档覆盖率"
      
    # 规范检查
    compliance_check:
      - "命名规范执行率"
      - "分层规范执行率"
      - "指标字典覆盖率"
      
    # 问题跟踪
    issue_tracking:
      - "上月问题清单"
      - "整改完成率"
      - "新增问题"
      
  audit_output:
    - "治理月报"
    - "整改清单"
    - "改进建议"
```

---

## 5. 公共资产库

> **职责边界**：本节描述**公共资产的治理职责**（owner 制度、准入/退出流程、复用机制）。
> **公共模型的字段结构与 SCD 策略**（如 dim_user/dim_product/dim_date 的具体字段、代理键、SCD2 实现）属 modeling-assistant 职责，详见 `modeling-assistant/references/data-modeling-standards.md`。
> **指标字典的完整定义**（原子/派生/衍生指标的编码、口径、修饰词、计算公式）属 modeling-assistant 职责，详见 `modeling-assistant/references/onedata-methodology.md`。

### 5.1 公共模型库（治理职责）

```yaml
public_models:
  # 治理职责：纳入/退出/owner/复用流程
  # 具体模型字段结构与 SCD 策略见 modeling-assistant/references/data-modeling-standards.md
  
  registry:
    - name: "dim_user"
      type: "一致性维度（SCD2）"
      owner: "用户域"
      access_process: "申请 → 域负责人审批 → 授权"
      
    - name: "dim_product"
      type: "一致性维度（SCD2）"
      owner: "商品域"
      
    - name: "dim_date"
      type: "一致性维度"
      owner: "数据平台"
      
    - name: "dwd_trade_order_detail"
      type: "公共明细表"
      owner: "交易域"
      usage: "所有订单相关分析的基础表，下游 DWS/ADS 直接引用"
      
  governance_rules:
    admission: "经数据架构评审委员会批准后方可纳入公共库"
    owner_must: "必须有明确 owner 与 owner_team"
    retirement: "长期无消费（孤儿）或被新模型替代后，走下线流程退出公共库"
```

### 5.2 指标字典（治理职责）

```yaml
metrics_dictionary:
  # 治理职责：保证指标"有字典、有 owner、无重复口径"
  # 指标定义、编码、口径、修饰词、计算公式见 modeling-assistant/references/onedata-methodology.md
  
  governance_rules:
    must_registered: "所有上线指标必须在指标字典注册"
    no_duplicate: "同一业务口径禁止多个指标定义（重复口径触发合并）"
    owner_must: "每个指标必须有 owner 域"
    change_control: "指标口径变更走 P0/P1 变更审批"
```

---

## 6. 治理报告模板

```markdown
# 数仓治理月报

## 1. 概况

| 指标 | 本月 | 上月 | 变化 |
|------|------|------|------|
| 总表数 | N | N | +N |
| 规范执行率 | N% | N% | +N% |
| 负责人覆盖率 | N% | N% | +N% |
| 问题数 | N | N | -N |

## 2. 资产变化

### 新增资产
| 类型 | 数量 | 影域 | 负责人 |
|------|------|------|--------|
| 表 | N | {域} | {人} |
| 任务 | N | {域} | {人} |

### 下线资产
| 类型 | 数量 | 原因 |
|------|------|------|
| 表 | N | 重复/过期 |
| 任务 | N | 合并/废弃 |

## 3. 规范执行

| 规范项 | 执行率 | 问题数 |
|--------|--------|--------|
| 命名规范 | N% | N |
| 分层规范 | N% | N |
| 负责人规范 | N% | N |

## 4. 问题跟踪

| 问题类型 | 上月遗留 | 本月新增 | 本月解决 | 剩余 |
|----------|---------|---------|---------|------|
| 结构问题 | N | N | N | N |
| 规范问题 | N | N | N | N |
| 质量问题 | N | N | N | N |

## 5. 改进建议

1. {建议1}
2. {建议2}
3. {建议3}
```

---

## 7. 治理检查清单

```markdown
## 治理检查清单（月度）

### 资产管理
- [ ] 资产清单已更新
- [ ] 新增资产已纳入治理
- [ ] 下线资产已清理
- [ ] 负责人信息完整

### 规范执行
- [ ] 命名规范检查完成
- [ ] 分层规范检查完成
- [ ] 跨层依赖检查完成
- [ ] 问题清单已整改

### 血缘管理
- [ ] 血缘图谱已更新
- [ ] 新增依赖已录入
- [ ] 血缘准确性验证

### 质量监控
- [ ] 质量监控正常运行
- [ ] 告警及时处理
- [ ] 质量报告已生成

### 复用推广
- [ ] 公共模型库更新
- [ ] 指标字典更新
- [ ] 复用率统计
```