# 数据开发工程师技能套件

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-blue)](https://claude.ai)

专为数据开发工程师设计的AI技能工具集，包含6个核心模块，支持端到端数据开发工作流。

## 🎯 项目概述

**数据开发工程师技能套件**是一个全面的数据开发解决方案，覆盖从需求分析到数据测试的完整数据开发生命周期。通过6个智能模块的协同工作，帮助数据工程师高效完成数据仓库建设、SQL开发、数据质量管理等任务。

## 📦 核心模块

### 1. 需求分析助手 (`/requirement-analyst`)
- **功能**：业务需求分析、功能规格定义、非功能性需求识别
- **输出**：需求规格文档、数据字典、验收标准
- **适用场景**：项目启动、需求澄清、范围定义

### 2. 数据建模助手 (`/modeling-assistant`)
- **功能**：OneData方法论（数据域划分/总线矩阵/指标体系）+ Kimball维度建模（事实表/维度表/SCD策略）
- **输出**：数据模型设计、DDL定义、模型文档
- **适用场景**：数仓建设、模型设计、Schema管理
- **核心方法论**：
  - 自顶向下规划：[OneData 建模理论](modeling-assistant/references/onedata-methodology.md) — 数据域、总线矩阵、指标体系
  - 自底向上设计：[Kimball 维度建模](modeling-assistant/references/data-modeling-standards.md) — 事实表、维度表、SCD

### 3. SQL智能开发助手 (`/sql-assistant`)
- **功能**：SQL生成、代码审查、执行计划分析
- **输出**：优化后的SQL代码、审查报告、性能建议
- **适用场景**：查询开发、性能优化、代码Review

### 4. 数据质量检查助手 (`/dq-assistant`)
- **功能**：质量规则生成、数据质量检查、质量文档输出
- **输出**：质量规则集、检查报告、数据字典
- **适用场景**：数据质量管理、数据监控、数据治理

### 5. 测试工程师 (`/test-engineer`)
- **功能**：单元测试、集成测试、性能测试、回归测试
- **输出**：测试用例、测试报告、性能基准
- **适用场景**：数据测试、质量保障、发布验证

### 6. 数仓重构助手 (`/dw-refactor-assistant`)
- **功能**：资产盘点、血缘分析、重复检测、迁移计划、治理框架
- **输出**：资产清单、问题报告、迁移计划、治理方案
- **适用场景**：烟囱式数仓治理、模型重复清理、依赖关系梳理
- **核心方法论**：5阶段重构（现状盘点 → 模型标准化 → 血缘分析 → 渐进迁移 → 持续治理）

## 🗄️ 支持的数据库

| 数据库 | 类型 | 说明 |
|--------|------|------|
| **AnalyticDB MySQL** | 阿里云数仓 | 数仓底座，存储主要业务数据 |
| **MaxCompute** | 阿里云大数据 | 存储埋点日志、行为日志、性能日志 |

## 🛠️ 技术栈

> 完整技术栈清单及官方文档链接详见 [SKILL.md](SKILL.md)（"技术栈总览"章节）

| 类别 | 组件 |
|------|------|
| 数仓底座 | AnalyticDB MySQL |
| 大数据计算 | MaxCompute |
| 开发治理 | DataWorks 标准版 |
| 数据可视化 | Quick BI |
| 实时计算 | Flink |
| 消息队列 | Kafka |
| 任务调度 | DolphinScheduler（自建 ECS） |
| 数据同步 | DataX（自建 ECS） |
| 开发语言 | SQL / Java / Python / Shell |
| 建模方法 | OneData + Kimball |

## 🚀 快速开始

### 安装方式

```bash
# 方式1：克隆项目并全局安装
git clone https://github.com/sqlking22/data-engineer-skills.git
cp -r data-engineer-skills ~/.claude/skills/

# 方式2：项目级安装（推荐）
git clone https://github.com/sqlking22/data-engineer-skills.git
cp -r data-engineer-skills /path/to/project/.claude/skills/

# 方式3：直接下载
# 从 GitHub Releases 下载最新版本，解压后复制到 skills 目录
```

> **提示**：安装后重启 Claude Code 即可使用所有 Skill 命令。

### 基本使用

```bash
# 完整工作流
/skill-hub 端到端建设电商数仓

# 单独使用模块
/requirement-analyst 分析需求
/modeling-assistant 设计模型
/sql-assistant 生成SQL
/dq-assistant 建立质量规则
/test-engineer 生成测试
```

## 🔗 智能联动系统

本Skill套件的核心特色是模块间的智能联动：

```
需求分析 → 数据建模 → SQL开发 → 数据质量 → 数据测试
```

### 标准数据包格式

每个模块输出标准化的YAML数据包，便于模块间数据交换：

```yaml
# requirement_package.yaml 示例
version: "1.0"
metadata:
  project_name: "电商用户行为分析"
  generated_by: "requirement-analyst"
content:
  functional:
    entities: ["用户", "订单", "商品"]
    metrics: ["日活用户", "转化率"]
```

### 预定义工作流

1. **完整数据开发流程** (`/skill-hub 端到端开发`)
2. **建模到SQL** (`/modeling-assistant → /sql-assistant`)
3. **SQL到质量测试** (`/sql-assistant → /dq-assistant → /test-engineer`)
4. **质量到测试** (`/dq-assistant → /test-engineer`)

## 📁 项目结构

```
data-engineer-skills/
├── SKILL.md                    # 主Skill定义
├── README.md                   # 本文档
├── skill-connections.yaml      # Skill联动配置
├── skill-hub.md               # 联动中枢文档
│
├── requirement-analyst/        # 需求分析模块
│   ├── SKILL.md
│   ├── references/
│   ├── examples/
│   └── scripts/
│
├── modeling-assistant/         # 数据建模模块
│   ├── SKILL.md
│   ├── references/
│   ├── examples/
│   └── scripts/
│
├── sql-assistant/             # SQL开发模块
│   ├── SKILL.md
│   ├── references/
│   ├── examples/
│   └── scripts/
│
├── dq-assistant/              # 数据质量模块
│   ├── SKILL.md
│   ├── references/
│   ├── examples/
│   └── scripts/
│
├── test-engineer/             # 数据测试模块
│   ├── SKILL.md
│   ├── references/
│   ├── examples/
│   └── scripts/
│
├── dw-refactor-assistant/     # 数仓重构模块
│   ├── SKILL.md
│   ├── references/
│   ├── examples/
│   └── scripts/
│
└── docs/                      # 文档目录
    ├── 使用指南.md
    ├── 扩展指南.md
    ├── 快速开始.md
    └── 最佳实践.md
```

## 📚 学习资源

### 文档目录

| 文档 | 内容 | 场景 |
|------|------|------|
| `docs/使用指南.md` | 各模块详细使用方法 | 学习使用 |
| `docs/扩展指南.md` | 如何定制和扩展 | 二次开发 |
| `docs/快速开始.md` | 入门教程 | 新手入门 |
| `docs/最佳实践.md` | 最佳实践和经验总结 | 提高效率 |

### 各模块参考文档

| 模块 | 参考文档 | 示例 |
|------|----------|------|
| requirement-analyst | `references/requirement-standards.md` | `examples/` |
| modeling-assistant | `references/onedata-methodology.md` (OneData方法论) <br> `references/data-modeling-standards.md` (Kimball维度建模) <br> `references/model-design.md` (模型设计模板) <br> `references/schema-doc.md` (Schema文档生成) | `examples/` |
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
   - 明确指定数据库类型
   - 查看对应数据库的方言差异文档

### 获取帮助
- 查看各模块的故障排除章节
- 参考示例项目学习正确用法

## 🤝 贡献指南

我们欢迎所有形式的贡献！无论是：

- 🐛 **报告 Bug** - 提交 Issue 描述问题
- 💡 **提出新功能** - 分享你的想法
- 📝 **改进文档** - 修正错误或添加示例
- 🔧 **提交代码** - 修复 Bug 或实现新功能

### 贡献流程

1. Fork 本仓库
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 开发环境

```bash
# 克隆你的 Fork
git clone https://github.com/sqlking22/data-engineer-skills.git
cd data-engineer-skills

# 安装到 Claude Code skills 目录进行开发测试
cp -r . ~/.claude/skills/data-engineer-skills

# 修改后重新复制以测试更改
```

详细开发指南请参阅 `docs/扩展指南.md`。

## 📄 许可证

本项目采用 **MIT 许可证** - 查看 [LICENSE](LICENSE) 文件了解详情。

这意味着你可以：
- ✅ 商业使用
- ✅ 修改代码
- ✅ 分发代码
- ✅ 私人使用

只需保留版权声明和许可证副本。

## 🙏 致谢

感谢以下开源项目和社区的支持：

- [Claude Code](https://claude.ai) - 由 Anthropic 提供的 AI 编程助手
- [阿里云 AnalyticDB](https://www.aliyun.com/product/apsaradb/ads) - 云原生数据仓库
- [阿里云 MaxCompute](https://www.aliyun.com/product/bigdata/ide) - 大数据计算服务
- Kimball Group - 维度建模方法论
- 阿里巴巴 OneData 团队 - 数据治理方法论

## 📞 联系方式

- **项目主页**: https://github.com/sqlking22/data-engineer-skills
- **问题反馈**: [GitHub Issues](https://github.com/sqlking22/data-engineer-skills/issues)
- **讨论区**: [GitHub Discussions](https://github.com/sqlking22/data-engineer-skills/discussions)

---

## 🔄 版本管理

### 当前版本：v1.0.0
- ✅ 6个核心模块完整功能
- ✅ 智能联动系统
- ✅ 标准化数据包格式
- ✅ 支持 AnalyticDB MySQL、MaxCompute

### 更新日志

查看 [CHANGELOG.md](CHANGELOG.md) 了解版本历史和更新内容。

---

**数据开发工程师技能套件** - 让数据开发更智能、更高效、更可靠。

🔧 *专注核心数据开发能力，打造高质量数据产品*

⭐ **如果这个项目对你有帮助，请给个 Star 支持一下！**