---
name: modeling-assistant
description: |
  数据建模助手 - 端到端数据建模工作流。融合 OneData 建模理论（数据域划分、总线矩阵、指标体系）与 Kimball 维度建模（事实表/维度表/SCD策略）形成"自顶向下规划 + 自底向上设计"完整闭环。
  支持MaxCompute、AnalyticDB MySQL数据库。
  当用户需要设计数据仓库模型、定义表结构Schema时触发。
  触发词：数据建模、维度建模、OneData、模型设计、Schema设计、数据域划分、总线矩阵、指标体系、表结构设计。
---

# 数据建模助手

从业务需求到数据模型设计的完整工作流。两个核心阶段：模型设计 → Schema文档。

## 架构概览

```
输入 → [阶段1: 模型设计] → [阶段2: Schema文档] → 输出
            │                     │
            ▼                     ▼
       Agent:通用            Agent:通用
```

| 阶段 | 命令 | Agent | 功能 |
|------|------|-------|------|
| 1 | /model-design | general-purpose | 维度建模设计（星型/雪花） |
| 2 | /schema-doc | general-purpose | 生成Schema定义和数据字典 |

**输入**: requirement_package.yaml（可选）
**输出**: modeling_package.yaml（驱动SQL开发和质量检查）

## 支持的数据库

| 数据库 | 分区策略 | 分布策略 | 特殊特性 |
|--------|---------|---------|---------|
| **MaxCompute** | 分区字段定义 | 自动分布 | 生命周期管理 |
| **AnalyticDB MySQL** | PARTITION BY VALUE | DISTRIBUTED BY HASH | 聚簇索引 |

## 参考资料导航

| 何时读取 | 文件 | 内容 | 场景 |
|---------|------|------|------|
| OneData 方法论 | [references/onedata-methodology.md](references/onedata-methodology.md) | 数据域划分、总线矩阵、指标体系、分层落地规范 | 自顶向下规划 |
| 维度建模规范 | [references/data-modeling-standards.md](references/data-modeling-standards.md) | 维度建模概念、设计模式、命名规范、ADB DDL 模板 | 维度模型设计 |
| 模型设计时 | [references/model-design.md](references/model-design.md) | 字段定义、约束规范、模型设计模板 | 定义表结构 |
| Schema设计时 | [references/schema-doc.md](references/schema-doc.md) | 数据字典、血缘分析、样例数据 | 生成文档 |
| **最佳实践指南** | [references/best-practices.md](references/best-practices.md) | **反模式、命名反例、粒度陷阱、SQL 示例、踩坑教训** |

---

## 示例快速索引

| 需求场景 | 推荐命令 | 上游输入 | 详情位置 |
|----------|----------|----------|----------|
| 设计维度模型 | `/model-design [需求]` | requirement_package.yaml | [功能1](#功能1模型设计) |
| 生成Schema文档 | `/schema-doc [模型]` | 模型设计结果 | [功能2](#功能2schema文档生成) |
| 端到端建模 | `/modeling-assistant [需求]` | 上游包 | [方式2](#方式2端到端工作流) |
| 生成SQL | 调用 `/sql-assistant` | modeling_package.yaml | [下游联动](#与下游-skill-的联动) |
| 质量检查 | 调用 `/dq-assistant` | modeling_package.yaml | [下游联动](#与下游-skill-的联动) |

---

## 上游输入

本 Skill 可消费以下标准包自动识别建模需求：

| 来源 Skill | 输入文件 | 关键字段 | 使用方式 |
|-----------|----------|----------|----------|
| requirement-analyst | requirement_package.yaml | functional.entities | 设计事实表和维度表 |
| requirement-analyst | requirement_package.yaml | functional.metrics | 设计度量字段 |

### 基于上游包的自动建模

```bash
# 方式1: 显式引用上游包
/model-design 基于 requirement_package.yaml 设计维度模型

# 方式2: 自动发现上游包
/model-design --auto  # 自动读取 outputs/ 中的上游包
```

---

## 快速开始

### 方式1：分阶段使用（推荐）

```bash
# 阶段1: 模型设计
/model-design 为电商订单系统设计维度模型：
- 业务流程：订单销售
- 分析需求：销售趋势、用户消费分析
- 数据库：MaxCompute

# 阶段2: Schema文档生成
/schema-doc 基于以上模型生成完整Schema定义
```

### 方式2：端到端工作流

```bash
# 启动完整建模工作流
/modeling-assistant 端到端建模：电商销售数据仓库
```

## 核心功能详解

### 功能1：模型设计 (/model-design)

**Agent类型**：general-purpose
**工具权限**：Read, Grep, Glob, Edit, Write, Bash

**使用场景**：
- 新数据仓库建模
- 业务系统数仓化
- 模型重构优化

**输入格式**：
```
/model-design 业务场景描述和模型需求
```

**输出内容**：
- 业务背景分析
- 模型架构图（星型/雪花）
- 事实表设计（粒度、维度、度量）
- 维度表设计（SCD策略）
- 物理设计建议（分区、分布键）

**示例**：
```
/model-design
业务流程：电商订单销售
分析需求：销售趋势、用户行为、商品分析
数据源：订单表、用户表、商品表、订单明细表
数据量：日增100万订单，历史1亿订单
数据库：MaxCompute
特殊需求：需要追踪用户等级变化历史
```

### 功能2：Schema文档生成 (/schema-doc)

**Agent类型**：general-purpose
**工具权限**：Read, Grep, Glob, Edit, Write, Bash

**使用场景**：
- 生成数据字典
- 定义表结构
- 文档化Schema

**输出内容**：
- 完整的表结构定义
- 字段类型和约束
- 索引定义
- 分区/分布策略

---

## 标准输出格式

每个数据建模任务输出标准化的 `modeling_package.yaml`：

```yaml
modeling_package:
  version: "1.0"
  metadata:
    generated_by: "modeling-assistant"
    generated_at: "2024-01-15T10:00:00Z"
    source_package: "requirement_package.yaml"
    project_name: "电商数据仓库"
    database: "MaxCompute"  # MaxCompute / ADB MySQL

  models:
    fact_tables:
      - name: "fct_order_items"
        grain: "订单项级别"
        description: "订单商品项事实表"
        dimensions:
          - dim_date
          - dim_user
          - dim_product
        measures:
          - name: "quantity"
            type: "integer"
          - name: "total_amount"
            type: "decimal(18,2)"
        partition_key: "pt"  # MaxCompute分区键
        distribution_key: "order_id"  # ADB分布键

    dimensions:
      - name: "dim_user"
        scd_type: 2  # SCD Type 2（默认，保留历史）
        natural_key: "user_id"
        attributes:
          - name: "user_id"
            type: "BIGINT"
          - name: "username"
            type: "VARCHAR(100)"
          - name: "city"
            type: "VARCHAR(50)"

  schemas:
    fct_order_items:
      database: "MaxCompute"
      columns:
        - name: "order_id"
          type: "BIGINT"
          primary_key: true
        - name: "user_id"
          type: "BIGINT"
        - name: "order_time"
          type: "DATETIME"
      partition:  # MaxCompute分区定义
        - name: "pt"
          type: "STRING"
          comment: "月分区 YYYYMM"
        - name: "dt"
          type: "STRING"
          comment: "日分区 DD"

  # ADB MySQL特有配置
  adb_config:
    distributed_by: "order_id"
    partition_by: "DATE_FORMAT(order_time, '%Y%m')"

  downstream_specs:
    - target: "sql-assistant"
      input_file: "modeling_package.yaml"
      mapping:
        - "schemas → ddl_input"
        - "fact_tables → tables"

    - target: "dq-assistant"
      input_file: "modeling_package.yaml"
      mapping:
        - "schemas → table_schemas"
```

---

## 与下游 Skill 的联动

数据建模完成后，自动触发下游 Skill：

```bash
## 建模后的下一步

# 步骤1: SQL开发（推荐）
/sql-assistant 基于以下模型生成DDL和查询SQL：
- 输入文件: outputs/modeling_package.yaml
- 表结构: schemas 定义
- 事实表: fact_tables 列表
- 维度表: dimensions 列表

# 步骤2: 数据质量检查
/dq-assistant 为以下模型建立质量规则：
- 输入文件: outputs/modeling_package.yaml
- 表结构: schemas 用于字段级规则
```

---

## 不同数据库建模差异

### MaxCompute 建模

```yaml
# 分区表设计
partition:
  - name: "pt"
    type: "STRING"
    comment: "月分区"
  - name: "dt"
    type: "STRING"
    comment: "日分区"

# 生命周期
lifecycle: 365  # 天

# 特点
- 无需分布键（自动分布）
- 分区是必须考虑的设计点
- 支持增量更新
```

### AnalyticDB MySQL 建模

```yaml
# 分布键设计
distributed_by: "order_id"  # 高基数字段

# 分区策略
partition_by: "DATE_FORMAT(order_time, '%Y%m')"  # 按月分区

# 聚簇索引
clustered_index:
  columns: ["user_id", "order_time"]
  comment: "优化用户维度查询"

# 主键约束
primary_key: ["order_id", "order_time"]  # 必须包含分区键
```

---

## 最佳实践

> 📖 **完整最佳实践指南**：[references/best-practices.md](references/best-practices.md) — 包含反模式、命名反例、粒度陷阱、SQL 示例、踩坑教训。

### 0. 速查卡片

| 卡片 | 核心原则 |
|------|---------|
| 🏗️ 先 OneData 后 Kimball | 先做数据域划分和总线矩阵，再做表级设计 |
| 🔬 粒度先于一切 | 事实表设计前必须明确粒度 |
| 🔗 维度一致性 | 同一维度在所有业务过程必须一致 |
| 📛 命名规范化 | 表名 `{layer}_{domain}_{entity}`，字段 snake_case |
| 📜 SCD 策略明确 | 默认 SCD Type 2，除非明确不需要历史 |
| ⬆️ 分层单向依赖 | ADS → DWS → DWD → ODS，禁止反向 |
| 🔢 代理键优先 | 维度表使用 BIGINT 代理键 |
| ♻️ 公共模型复用 | 优先用 dim_user / dim_date 等公共维度 |

### 1. 模型设计原则

**粒度原则**：
- 事实表粒度应是最细的业务级别
- 同一事实表的所有度量必须在相同粒度

**维度原则**：
- 维度表应包含丰富的描述属性
- 根据业务需求选择SCD策略

**命名原则**：
- 事实表：`fct_` 前缀
- 维度表：`dim_` 前缀
- 清晰、一致、有意义

### 2. 数据库选择建议

| 数据库 | 适用场景 | 模型特点 |
|--------|---------|---------|
| MaxCompute | 海量离线处理（日志/埋点） | 分区设计、生命周期 |
| ADB MySQL | OLAP数仓（业务数据） | 分布键、分区、聚簇索引 |

---

## 故障排除

### 模型设计不符合预期
1. 提供更详细的业务场景描述
2. 明确数据量和性能要求
3. 说明已有的数据源结构

### Schema生成失败
1. 检查模型定义是否完整
2. 确认数据库类型已指定
3. 验证字段类型映射

---

## 示例场景

详见 [examples/](examples/) 目录。

---

## 路线图

### v1.0.0 (当前)
- ✅ 维度模型设计
- ✅ Schema文档生成
- ✅ MaxCompute支持
- ✅ ADB MySQL支持

---

**提示**：本Skill专注于数据模型设计，生成的modeling_package.yaml可直接传递给sql-assistant生成DDL。