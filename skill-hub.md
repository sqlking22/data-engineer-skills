---
name: skill-hub
description: |
  数据开发Skill联动中枢 - 协调需求分析、数据建模、SQL开发、数据质量、数据测试之间的协作。
  触发词：端到端开发、skill联动、完整工作流、自动化开发、data-workflow。
argument: { description: "联动需求描述（如：端到端建设电商数仓）", required: true }
agent: general-purpose
allowed-tools: [Agent, Read, Grep, Glob, Edit, Write, Bash]
---

# 数据开发Skill Hub

## 功能

协调多个数据开发Skill，实现端到端自动化开发工作流。

> 详细联动配置见: [skill-connections.yaml](skill-connections.yaml)

## 支持的联动模式

| 模式 | 说明 | 示例 |
|------|------|------|
| 简单串联 | A → B | 建模 → SQL生成 |
| 并行分流 | A → [B, C] | 模型设计 → 并行生成SQL和Quality |
| 完整工作流 | 多阶段流程 | 建模→SQL→质量→测试 |

## 联动矩阵

```
                需求分析    数据建模    SQL开发    数据质量    数据测试    数仓重构
                助手        助手       助手       检查助手     工程师     助手
需求分析助手       -        ✓(需求→模型) ✓(需求→SQL) ✓(需求→规则) ✓(需求→测试)  ✓(需求→重构)
数据建模助手    ✓(模型→需求)    -       ✓(Schema) ✓(质量)      ✓(测试)     ✓(模型→重构)
SQL开发助手     ✓(SQL→需求) ✓(SQL→模型)   -       ✓(规则)      ✓(测试)     ✓(SQL→重构)
数据质量助手     ✓(质量→需求) ✓(质量→模型) ✓(规则)      -       ✓(测试)     ✓(质量→重构)
测试工程师     ✓(测试→需求) ✓(测试→模型) ✓(测试→SQL) ✓(测试→质量)     -     ✓(测试→重构)
数仓重构助手   ✓(重构→需求) ✓(重构→模型) ✓(重构→SQL) ✓(重构→质量) ✓(重构→测试)  -
```

## 工作流模板

### 模板1: 端到端数据开发流程

```yaml
workflow: full_development_pipeline
phases:
  - name: 需求分析
    skill: requirement-analyst
    input: 原始业务需求
    output: 结构化需求包

  - name: 数据建模
    skill: modeling-assistant
    input: 需求包
    output: 维度模型设计

  - name: SQL开发
    skill: sql-assistant
    input: 模型Schema
    output: DDL + 查询SQL

  - name: 数据质量
    skill: dq-assistant
    input: 目标表Schema
    output: 质量规则

  - name: 数据测试
    skill: test-engineer
    input: 数据质量包 + SQL包
    output: 测试套件
```

### 模板2: 建模到SQL开发

```yaml
workflow: modeling_to_sql
phases:
  - name: 模型设计
    skill: modeling-assistant
    input: 建模需求
    output: 模型设计文档

  - name: SQL生成
    skill: sql-assistant
    input: 模型Schema
    output: DDL和ETL SQL

  - name: SQL审查
    skill: sql-assistant
    input: SQL代码
    output: 优化后的SQL

  - name: 质量规则
    skill: dq-assistant
    input: 表Schema
    output: 质量规则配置
```

### 模板3: SQL开发到测试

```yaml
workflow: sql_to_test
phases:
  - name: SQL生成
    skill: sql-assistant
    input: 业务需求
    output: SQL初稿

  - name: 质量检查
    skill: dq-assistant
    input: SQL结果Schema
    output: 质量规则

  - name: 测试生成
    skill: test-engineer
    input: 质量规则
    output: 测试用例
```

## 当前需求

$ARGUMENTS

---

**执行策略**：
1. 解析需求，识别需要哪些Skill
2. 确定执行顺序和依赖关系
3. 依次调用各Skill，传递上下文
4. 整合输出，形成完整项目包

**示例**：
```
需求: "端到端建设电商订单数仓"
识别: 需要 requirement → modeling → sql → dq → test
执行: 按顺序调用，传递Schema和上下文
输出: 模型+SQL+质量规则+测试用例完整包
```

## 详细联动指南

### 联动1: 需求分析 → 数据建模

当用户从业务需求开始数据平台建设时：

```bash
# 用户输入
/requirement-analyst 分析电商销售分析需求 → /modeling-assistant 基于需求设计数据模型

# 系统自动
1. requirement-analyst 解析需求，输出requirement_package.yaml
   - 提取业务实体、指标、维度
2. 将requirement_package传递给modeling-assistant
3. modeling-assistant 根据需求设计维度模型
   - 设计事实表和维度表
   - 定义SCD策略
4. 输出modeling_package.yaml
```

---

### 联动2: 数据建模 → SQL开发

当模型确定后，基于Schema生成SQL：

```bash
# 用户输入
/modeling-assistant 完成维度模型设计 → /sql-assistant 基于模型生成DDL

# 系统自动
1. modeling-assistant 输出模型设计
   - 事实表和维度表Schema
2. 提取模型中的表结构、字段类型、关系
3. 传递给sql-assistant生成DDL和查询SQL
4. 输出sql_package.yaml
```

---

### 联动3: 数据建模 → 数据质量

当模型确定后，生成质量规则：

```bash
# 用户输入
/modeling-assistant 完成模型设计 → /dq-assistant 为模型建立质量规则

# 系统自动
1. modeling-assistant 输出表Schema
2. dq-assistant 分析Schema，生成质量规则
   - 字段非空检查
   - 主键唯一性检查
   - 数值范围检查
3. 输出dq_package.yaml
```

---

### 联动4: SQL开发 → 数据质量

当SQL开发完成后，建立质量监控：

```bash
# 用户输入
/sql-assistant 生成查询SQL → /dq-assistant 为结果建立质量监控

# 系统自动
1. sql-assistant 输出SQL包
2. dq-assistant 分析SQL结果Schema
3. 生成对应的质量规则
4. 输出dq_package.yaml
```

---

### 联动5: 数据质量 → 数据测试

当质量规则确定后，生成测试用例：

```bash
# 用户输入
/dq-assistant 生成质量规则 → /test-engineer 基于规则生成测试

# 系统自动
1. dq-assistant 生成质量规则配置
2. 提取规则类型和字段信息
3. 传递给test-engineer生成测试用例
4. 输出test_package.yaml
```

---

### 联动6: 端到端工作流

完整的数据开发流程（5阶段）：

```bash
# 用户输入
/skill-hub 端到端建设电商数仓：包含用户、订单、商品数据，支持销售分析

# 系统自动执行完整工作流
Phase 0: 需求分析 (requirement-analyst)
  - /requirement-analyst: 解析业务需求，提取实体、指标、维度
  - 输出: requirement_package.yaml

Phase 1: 数据建模 (modeling-assistant)
  - /modeling-assistant: 基于需求设计维度模型
  - 输出: modeling_package.yaml

Phase 2: SQL开发 (sql-assistant)
  - /sql-assistant: 生成DDL和查询SQL
  - 输出: sql_package.yaml

Phase 3: 数据质量 (dq-assistant)
  - /dq-assistant: 生成质量规则
  - 输出: dq_package.yaml

Phase 4: 数据测试 (test-engineer)
  - /test-engineer: 生成测试用例
  - 输出: test_package.yaml

Phase 5: 项目整合
  - 输出完整项目结构
  - 包含所有代码和文档
```

## 上下文传递协议

### requirement-analyst 输出格式

```yaml
# 标准化需求包 (requirement_package.yaml)
requirement_package:
  version: "1.0"
  metadata:
    project_name: "项目名称"
    confirmed: true

  business:
    domain: "业务域"
    goal: "业务目标"

  functional:
    entities: [...]      # 传递给 modeling-assistant
    metrics: [...]       # 传递给 sql-assistant
    dimensions: [...]    # 传递给 modeling-assistant

  specifications:
    model_spec: {...}    # 传递给 modeling-assistant

  downstream_tasks:
    - skill: "modeling-assistant"
    - skill: "sql-assistant"
    - skill: "dq-assistant"
```

### modeling-assistant 输出格式

```yaml
# 模型设计包 (modeling_package.yaml)
modeling_package:
  version: "1.0"
  source: "requirement-analyst"

  fact_tables:
    - name: "fct_order_items"
      grain: "订单项级别"
      dimensions: ["dim_date", "dim_user", "dim_product"]
      measures:
        - name: "quantity"
          type: "integer"
        - name: "amount"
          type: "decimal"

  dimensions:
    - name: "dim_user"
      scd_type: 2
      natural_key: "user_id"

  schemas:
    fct_order_items:
      columns:
        - name: "order_id"
          type: "BIGINT"
          primary_key: true

  downstream_specs:
    - target: "sql-assistant"
      input_file: "modeling_package.yaml"
    - target: "dq-assistant"
      input_file: "modeling_package.yaml"
```

### 端到端数据流

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        完整Skill联动数据流                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  原始需求                                                                │
│     │                                                                   │
│     ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  requirement-analyst                                            │   │
│  │  输出: requirement_package.yaml                                  │   │
│  └────────────────────────┬────────────────────────────────────────┘   │
│                           │  [functional.entities]                       │
│                           ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  modeling-assistant                                             │   │
│  │  输入: requirement_package.yaml                                  │   │
│  │  输出: modeling_package.yaml                                     │   │
│  └────────────────────────┬────────────────────────────────────────┘   │
│                           │  [fact_tables, dimensions]                   │
│                           ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  sql-assistant                                                  │   │
│  │  输入: 模型Schema                                                │   │
│  │  输出: DDL + 查询SQL                                             │   │
│  └────────────────────────┬────────────────────────────────────────┘   │
│                           │  [目标Schema]                                │
│                           ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  dq-assistant                                                   │   │
│  │  输入: 目标表Schema                                              │   │
│  │  输出: 质量规则 + 数据字典                                       │   │
│  └────────────────────────┬────────────────────────────────────────┘   │
│                           │  [quality_rules, table_schemas]              │
│                           ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  test-engineer                                                  │   │
│  │  输入: 质量规则 + 表Schema                                       │   │
│  │  输出: 单元测试 + 集成测试                                       │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  完整项目交付 (模型 + SQL + 质量规则 + 测试用例 + 文档)                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## 使用示例

### 示例1: 端到端数仓建设

```bash
用户: 端到端建设电商销售分析数仓

系统执行完整5阶段工作流:

Phase 0 (需求分析助手):
  - 解析业务需求
  - 提取实体(订单/用户/商品)、指标(GMV/订单量)、维度(日期/地区)
  - 输出: requirement_package.yaml

Phase 1 (数据建模助手):
  - 基于需求设计星型模型
  - 输出: dim_user, dim_product, fct_order_items
  - 输出: modeling_package.yaml

Phase 2 (SQL开发助手):
  - 生成维度表DDL
  - 生成事实表DDL
  - 输出: SQL脚本集合

Phase 3 (数据质量助手):
  - 为所有表生成质量规则
  - 输出: DQ配置

Phase 4 (测试工程师):
  - 生成单元测试 (schema/数据质量/业务逻辑)
  - 输出: pytest测试套件
```

### 示例2: 快速建模到SQL

```bash
用户: 帮我设计订单模型并生成DDL

系统:
┌─────────────────────────────────────────────────────────┐
│ Step 1: 数据建模助手                                     │
│ /modeling-assistant 设计订单维度模型                     │
│ 输出: modeling_package.yaml                              │
├─────────────────────────────────────────────────────────┤
│ [自动传递上下文]                                         │
│ 模型 → 表结构提取 → Schema信息                           │
├─────────────────────────────────────────────────────────┤
│ Step 2: SQL智能开发助手                                  │
│ /sql-assistant 基于Schema生成DDL                         │
│ 输出: DDL脚本                                            │
└─────────────────────────────────────────────────────────┘

最终输出: 模型 + DDL代码包
```

### 示例3: 质量到测试

```bash
用户: 为订单表建立质量监控并生成测试

系统:
┌─────────────────────────────────────────────────────────┐
│ Step 1: 数据质量助手                                     │
│ /dq-assistant 为订单表生成质量规则                       │
│ 输出: dq_package.yaml                                    │
├─────────────────────────────────────────────────────────┤
│ [自动传递上下文]                                         │
│ 规则 → 测试断言提取                                      │
├─────────────────────────────────────────────────────────┤
│ Step 2: 测试工程师                                       │
│ /test-engineer 基于质量规则生成测试                      │
│ 输出: test_package.yaml                                  │
└─────────────────────────────────────────────────────────┘
```