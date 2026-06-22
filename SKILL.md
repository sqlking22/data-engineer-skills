---
name: data-engineer-skills
description: |
  数据开发工程师技能套件 - 专为数据开发工程师设计的AI技能工具集。
  包含6个核心模块：需求分析、数据建模、SQL开发、数据质量、数据测试、数仓重构。
  支持数据库：AnalyticDB MySQL、MaxCompute。
  触发词：数据开发、数据仓库、SQL优化、数据质量、数据建模、需求分析、数据测试。
---

# 数据开发工程师技能套件

专为数据开发工程师设计的完整AI Skill工具集，包含6个核心模块，支持端到端数据开发工作流。

## 🎯 核心价值

- **端到端覆盖**：从需求分析到数据测试的完整数据开发生命周期
- **模块化设计**：6个独立模块，可按需组合使用
- **智能联动**：模块间自动数据流转，减少重复工作
- **企业级标准**：遵循数据工程最佳实践和行业标准

## 📦 模块概览

| 模块 | 入口命令 | 核心功能 | 适用场景 |
|------|----------|----------|----------|
| **需求分析助手** | `/requirement-analyst` | 业务需求分析、功能规格定义 | 项目启动、需求澄清 |
| **数据建模助手** | `/modeling-assistant` | OneData方法论 + Kimball维度建模 | 数仓建设、模型设计 |
| **SQL智能开发助手** | `/sql-assistant` | SQL生成、审查、执行计划分析 | 查询开发、性能优化 |
| **数据质量检查助手** | `/dq-assistant` | 质量规则生成、检查、文档 | 数据质量管理 |
| **测试工程师** | `/test-engineer` | 单元测试、集成测试、性能测试 | 数据测试保障 |
| **数仓重构助手** | `/dw-refactor-assistant` | 资产盘点、血缘分析、迁移治理 | 烟囱式数仓治理与重构 |

## ⌨️ 命令速查表（新手先看这个）

> 记不住命令？**只需记住下面 6 个入口命令**即可，每个入口都能独立完成整个模块的工作；阶段子命令仅供精细控制时使用。不确定用哪个时，直接用 `/skill-hub`。

### 入口命令（记这 6 个就够）

| 我想做的事 | 直接用这个命令 |
|-----------|---------------|
| 梳理业务需求、产出需求文档 | `/requirement-analyst` |
| 设计数仓模型（事实表/维度表） | `/modeling-assistant` |
| 写 SQL、审查 SQL、优化慢查询 | `/sql-assistant` |
| 建数据质量规则、做质量检查 | `/dq-assistant` |
| 生成数据测试用例 | `/test-engineer` |
| 治理烟囱式数仓、做重构 | `/dw-refactor-assistant` |
| **端到端一条龙（不知道选哪个就用它）** | **`/skill-hub 端到端...`** |

### 分阶段子命令（精细控制时用）

| 模块 | 阶段子命令（按顺序） |
|------|---------------------|
| 需求分析 | `/requirement-parser` → `/requirement-clarify` → `/requirement-transform` |
| 数据建模 | `/model-design`（设计模型）、`/schema-doc`（生成 Schema 文档） |
| SQL开发 | `/sql-gen`（生成）→ `/sql-review`（审查）→ `/sql-explain`（执行计划） |
| 数据质量 | `/dq-rule-gen`（规则）→ `/dq-check`（检查）→ `/dq-doc`（数据字典） |
| 数据测试 | `/unit-test` → `/integration-test` → `/performance-test` |
| 数仓重构 | `/asset-inventory` → `/model-standardize` → `/lineage-scan` → `/dup-detection` → `/impact-analysis` → `/refactor-plan` → `/governance-setup` |

### 常见场景一条龙

| 场景 | 推荐流程 |
|------|---------|
| 从零建数仓 | `/skill-hub 端到端建设XX数仓` |
| 已有模型，要生成 DDL | `/modeling-assistant` → `/sql-assistant` |
| 查询慢，要优化 | `/sql-explain`（贴执行计划）→ `/sql-gen`（重写优化） |
| 要保证数据质量 | `/dq-assistant` → `/test-engineer` |
| 数仓太乱要治理 | `/dw-refactor-assistant` |

> 💡 `→` 表示"先做前面的，再做后面的"。可用 `--from-xxx` 让下游命令自动读取上游产出，如 `/sql-assistant --from-model`。

## 🗄️ 支持的数据库

| 数据库 | 类型 | 支持程度 | 特殊说明 |
|--------|------|---------|---------|
| **AnalyticDB MySQL** | 阿里云数仓 | ✅ 完整支持 | 数仓底座，存储主要业务数据 |
| **MaxCompute** | 阿里云大数据 | ✅ 完整支持 | 存储埋点日志、行为日志、性能日志 |

## 🛠️ 技术栈总览

### 数据存储
| 组件 | 类型 | 用途 | 官方文档 |
|------|------|------|---------|
| **AnalyticDB MySQL** | 数仓底座 | 存储主要业务数据 | [官方文档](https://help.aliyun.com/product/190244.html) |
| **MaxCompute** | 大数据计算 | 存储埋点日志、行为日志、性能日志 | [官方文档](https://help.aliyun.com/product/27748.html) |

### 阿里云数据工具
| 组件 | 类型 | 用途 | 官方文档 |
|------|------|------|---------|
| **DataWorks**（标准版） | 数据开发治理平台 | 数据开发、调度、治理 | [官方文档](https://help.aliyun.com/product/72772.html) |
| **Quick BI** | 数据可视化 | 报表制作、数据可视化 | [官方文档](https://help.aliyun.com/product/43570.html) |
| **Flink**（实时计算） | 实时计算引擎 | 实时数据同步与处理 | [官方文档](https://help.aliyun.com/zh/flink/) |
| **Kafka**（消息队列） | 消息中间件 | 埋点日志采集与传输 | [官方文档](https://help.aliyun.com/product/26157.html) |

### 自建工具（部署于阿里云 ECS）
| 组件 | 类型 | 用途 | 官方文档 |
|------|------|------|---------|
| **DolphinScheduler** | 任务调度 | 工作流调度与编排（执行 Java/Python/Shell 脚本） | [官方文档](https://dolphinscheduler.apache.org/zh-cn/docs) |
| **DataX** | 数据同步 | 异构数据源离线同步 | [官方文档](https://github.com/alibaba/DataX) |

### 开发语言
| 语言 | 用途 |
|------|------|
| **SQL** | 核心查询与数据开发 |
| **Java** | 数据开发（Flink 作业等） |
| **Python** | 脚本开发（数据处理、工具集成） |
| **Shell** | 运维脚本（任务调度、监控） |

### 核心术语速览

> 如果你是数据开发新人，先花 1 分钟了解这些术语，再看后面的模块说明。

| 术语 | 全称 | 一句话解释 |
|------|------|-----------|
| **ODS** | Operational Data Store | 贴源层：从业务系统原样同步的原始数据，未清洗 |
| **DWD** | Data Warehouse Detail | 明细层：清洗后的事实表数据，保留最细粒度 |
| **DWS** | Data Warehouse Summary | 汇总层：按维度聚合的宽表，给报表用 |
| **ADS** | Application Data Service | 应用层：面向具体应用（报表/接口）的结果表 |
| **DIM** | Dimension | 维度表：描述"人/物/地点"的属性表（如用户表、商品表） |
| **事实表** | Fact Table | 记录业务事件的表（如订单表、日志表），含度量字段 |
| **SCD** | Slowly Changing Dimension | 缓慢变化维：维度属性随时间变化时的处理策略（Type 1=覆盖，Type 2=保留历史） |
| **ETL** | Extract-Transform-Load | 数据从源系统抽取→清洗转换→加载到数仓的全过程 |

### 数据仓库分层
```
ODS（贴源层） → DWD（明细层） → DWS（汇总层） → ADS（应用层）
                                DIM（维度层）
```

### 建模方法论
| 方法论 | 来源 | 适用场景 |
|--------|------|---------|
| **OneData 建模理论** | 阿里 | 阿里云数仓体系标准方法，数据域划分、总线矩阵 |
| **Kimball 维度建模** | Ralph Kimball | 星型模型、维度设计、SCD 策略 |

### 历史参考（团队不再使用，仅供对比参考）
| 组件 | 类型 | 备注 |
|------|------|------|
| Hologres | 实时数仓 | 团队已不再使用，此处保留作为技术对比参考 |

## 🚀 快速开始

### 方式1：端到端工作流（推荐）

```bash
# 完整数仓建设工作流
/skill-hub 端到端建设电商销售分析数仓

# 快速建模到SQL
/modeling-assistant → /sql-assistant 设计订单模型并生成DDL

# 质量到测试
/dq-assistant → /test-engineer 基于质量规则生成测试用例
```

### 方式2：独立模块使用

```bash
# 需求分析
/requirement-analyst 分析电商用户行为分析需求

# 数据建模
/modeling-assistant 设计用户行为维度模型

# SQL开发
/sql-assistant 使用MaxCompute语法生成用户活跃度分析SQL

# 数据质量
/dq-assistant 为用户表建立质量监控

# 数据测试
/test-engineer 生成用户数据测试用例
```

---

## 📋 示例快速索引

| 需求场景 | 推荐工作流 | 命令示例 |
|----------|-----------|----------|
| 从零建设数仓 | 端到端工作流 | `/skill-hub 端到端建设电商数仓` |
| 需求澄清 | 需求分析 | `/requirement-analyst 分析需求` |
| 数据建模 | 建模到SQL | `/modeling-assistant → /sql-assistant` |
| 生成SQL | SQL开发 | `/sql-assistant 生成查询` |
| 建立质量监控 | 质量到测试 | `/dq-assistant → /test-engineer` |

---

## 🔗 上下游联动说明

### 完整数据流

```
requirement_package.yaml
    ↓（业务需求、实体定义）
modeling_package.yaml
    ↓（事实表、维度表）
sql_package.yaml
    ↓（DDL、转换SQL）
dq_package.yaml
    ↓（质量规则）
test_package.yaml
    ↓（测试通过）
交付上线
```

### 快捷联动命令

| 联动 | 命令 | 输出 |
|------|------|------|
| 需求→建模 | `/modeling-assistant --from-requirement` | modeling_package.yaml |
| 建模→SQL | `/sql-assistant --from-model` | sql_package.yaml |
| SQL→质量 | `/dq-assistant --from-sql` | dq_package.yaml |
| 质量→测试 | `/test-engineer --from-dq` | test_package.yaml |

> 完整联动关系（含 `/sql-assistant --from-requirement`、`/dq-assistant --from-model`、`/test-engineer --from-model` 等）见 [skill-connections.yaml](skill-connections.yaml)。

---

## 🔗 智能联动系统

本Skill套件包含智能联动中枢，支持模块间自动数据流转：

```
需求分析 → 数据建模 → SQL开发 → 数据质量 → 数据测试
```

### 联动配置

查看详细联动关系：
```bash
# 查看Skill依赖关系
cat skill-connections.yaml

# 查看完整工作流定义
cat skill-hub.md
```

## 📁 项目结构

```
data-engineer-skills/
├── SKILL.md                    # 本文件（主Skill定义）
├── README.md                   # 项目说明
├── skill-connections.yaml      # Skill联动配置
├── skill-hub.md               # 联动中枢文档
├── requirement-analyst/        # 需求分析模块
├── modeling-assistant/         # 数据建模模块
├── sql-assistant/             # SQL开发模块
├── dq-assistant/              # 数据质量模块
├── test-engineer/             # 数据测试模块
└── dw-refactor-assistant/     # 数仓重构模块
```

## 📚 学习资源

### 套件文档

| 文档 | 内容 | 场景 |
|------|------|------|
| `README.md` | 详细功能说明和使用指南 | 了解套件全貌 |
| `skill-connections.yaml` | Skill联动配置 | 查看模块间关系 |
| `skill-hub.md` | 联动中枢文档 | 了解工作流定义 |
| `docs/使用指南.md` | 详细使用方法 | 学习各模块用法 |
| `docs/扩展指南.md` | 扩展开发指南 | 定制和扩展 |

### 各模块文档

| 模块 | 参考文档 | 示例 |
|------|----------|------|
| requirement-analyst | `references/requirement-standards.md` | `examples/` |
| modeling-assistant | `references/data-modeling-standards.md` | `examples/` |
| sql-assistant | `references/sql-standards.md` | `examples/` |
| dq-assistant | `references/data-quality-standards.md` | `examples/` |
| test-engineer | `references/test-standards.md` | `examples/` |

## 🆘 故障排除

### 常见问题

1. **Skill未触发**
   - 确认skill文件在正确的skills目录
   - 检查Frontmatter格式是否正确
   - 重启Claude Code

2. **模块联动失败**
   - 检查`skill-connections.yaml`配置
   - 确认输出包文件格式正确
   - 查看模块日志输出

3. **数据库语法问题**
   - 明确指定数据库类型（ADB MySQL / MaxCompute）
   - 查看对应数据库的方言差异文档

### 技术支持
- 查看各模块的故障排除章节
- 参考示例项目学习正确用法

---

**数据开发工程师技能套件** - 让数据开发更智能、更高效、更可靠。

🔧 *专注核心数据开发能力，打造高质量数据产品*