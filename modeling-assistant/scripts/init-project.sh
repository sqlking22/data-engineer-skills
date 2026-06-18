#!/bin/bash
# 数据建模项目初始化脚本
# 用法: bash init-project.sh <项目目录> <项目名称>
# 示例: bash init-project.sh ./modeling-project "数据仓库建模"

set -e

PROJECT_DIR="$1"
PROJECT_NAME="${2:-Data Modeling Project}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

if [ -z "$PROJECT_DIR" ]; then
    echo "❌ 错误: 请指定项目目录"
    echo "用法: bash init-project.sh <项目目录> [项目名称]"
    echo "示例: bash init-project.sh ./my-dw-project "电商数据仓库""
    exit 1
fi

# 创建目录结构
echo "🚀 创建数据建模项目: $PROJECT_NAME"
echo "📁 项目目录: $PROJECT_DIR"
mkdir -p "$PROJECT_DIR"/{models/{ods,dwd,dws,ads,dim},docs,scripts,configs}

# 复制规范文件
cp "$SKILL_DIR/references/data-modeling-standards.md" "$PROJECT_DIR/standards.md"

# 创建 PROJECT.md
cat > "$PROJECT_DIR/PROJECT.md" << 'EOF'
# PROJECT - 数据建模项目中枢

## 项目信息

- **项目名称**: PROJECT_NAME_PLACEHOLDER
- **创建时间**: CREATE_TIME_PLACEHOLDER
- **建模方法**: 维度建模（星型模型）+ OneData 建模理论
- **调度平台**: DolphinScheduler / DataWorks
- **数据库**: AnalyticDB MySQL / MaxCompute

## 数据仓库分层

```
ODS（贴源层） → DWD（明细层） → DWS（汇总层） → ADS（应用层）
                                DIM（维度层）
```

## 模型清单

| 模型名 | 层级 | 类型 | 粒度 | 状态 | 负责人 |
|--------|------|------|------|------|--------|
| | ODS | | | 🟡设计 | |
| | DWD | | | 🟡设计 | |
| | DIM | | | 🟡设计 | |
| | DWS | | | 🟡设计 | |
| | ADS | | | 🟡设计 | |

状态说明:
- 🟡 设计: 设计阶段
- 🟡 开发: 开发阶段
- 🟢 测试: 测试中
- 🟢 上线: 已上线
- 🔴 废弃: 已废弃

## 待办事项

### 模型设计
- [ ] 完成业务需求分析
- [ ] 确定数据域划分（OneData）
- [ ] 设计维度表
- [ ] 设计事实表

### 数据开发
- [ ] 配置数据源连接
- [ ] 开发ODS层模型
- [ ] 开发DWD层模型
- [ ] 开发DWS层模型
- [ ] 开发ADS层模型

### 调度配置
- [ ] 配置 DolphinScheduler 工作流
- [ ] 配置依赖关系
- [ ] 配置调度周期

### 文档
- [ ] 生成模型文档
- [ ] 生成数据字典
- [ ] 编写使用手册

## 快速链接

- [数据建模规范](./standards.md)
- [models/](./models/) - 模型目录
- [docs/](./docs/) - 文档目录
- [scripts/](./scripts/) - 脚本目录

## 使用流程

```bash
# 1. 进入项目目录
cd PROJECT_DIR_PLACEHOLDER

# 2. 启动 Claude Code
claude

# 3. 模型设计
/model-design 业务场景描述

# 4. SQL生成
/sql-gen 基于建模结果生成DDL

# 5. 生成数据字典
/schema-doc 生成模型文档
```
EOF

# 替换占位符
sed -i.bak "s/PROJECT_NAME_PLACEHOLDER/$PROJECT_NAME/g" "$PROJECT_DIR/PROJECT.md"
sed -i.bak "s/CREATE_TIME_PLACEHOLDER/$(date '+%Y-%m-%d')/g" "$PROJECT_DIR/PROJECT.md"
sed -i.bak "s|PROJECT_DIR_PLACEHOLDER|$PROJECT_DIR|g" "$PROJECT_DIR/PROJECT.md"
rm -f "$PROJECT_DIR/PROJECT.md.bak"

# 创建 README.md
cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

数据仓库建模项目，使用 Claude Modeling Assistant Skill 管理。

## 项目结构

\`\`\`
.
├── PROJECT.md          # 项目中枢（模型清单+进度+规范）
├── standards.md        # 数据建模规范
├── README.md           # 本文件
├── models/
│   ├── ods/            # ODS贴源层模型
│   ├── dwd/            # DWD明细层模型
│   ├── dws/            # DWS汇总层模型
│   ├── ads/            # ADS应用层模型
│   └── dim/            # DIM维度层模型
├── docs/               # 模型文档
├── scripts/            # SQL脚本
└── configs/            # 配置文件
\`\`\`

## 快速开始

### 1. 模型设计

\`\`\`bash
cd $PROJECT_DIR
claude

# 设计维度模型
/model-design 为[业务场景]设计数据模型
\`\`\`

### 2. SQL开发

\`\`\`bash
# 生成DDL
/sql-gen 基于模型设计生成建表DDL

# 生成ETL SQL
/sql-gen 生成ODS到DWD的转换SQL
\`\`\`

### 3. 数据字典

\`\`\`bash
# 生成数据字典
/schema-doc 生成完整数据字典文档
\`\`\`

### 4. 调度部署

\`\`\`bash
# 通过 DolphinScheduler 或 DataWorks 配置调度
# 参考 configs/ 目录下的调度配置
\`\`\`

## 开发流程

1. **需求分析**: /requirement-analyst → 输出需求规格
2. **模型设计**: /model-design → 输出模型设计方案
3. **SQL开发**: /sql-gen → 生成DDL和ETL SQL
4. **质量检查**: /dq-assistant → 配置质量规则
5. **测试验证**: /test-engineer → 执行数据测试
6. **调度上线**: 配置 DolphinScheduler/DataWorks → 部署到生产

## 规范

详见 [standards.md](./standards.md)

## 更新日志

### v1.0.0 ($(date '+%Y-%m-%d'))
- 项目初始化
EOF

# 创建 .gitignore
cat > "$PROJECT_DIR/.gitignore" << 'EOF'
# 环境配置
.env
*.conf

# 大型文件
*.csv
!seeds/.gitkeep 2>/dev/null

# 临时文件
*.tmp
*.bak
.DS_Store

# IDE
.idea/
.vscode/
*.swp
EOF

# 创建示例模型文件
for layer in ods dwd dws ads dim; do
  cat > "$PROJECT_DIR/models/$layer/.gitkeep" << EOF
# $layer 层模型文件
EOF
done

# 创建示例调度配置文件
cat > "$PROJECT_DIR/configs/dolphinscheduler_workflow.yaml" << 'EOF'
# DolphinScheduler 工作流配置示例
workflow:
  name: "数据仓库建模工作流"
  description: "从ODS到ADS的完整数据处理流程"

  tasks:
    - name: "ods_to_dwd"
      type: "SQL"
      description: "ODS层到DWD层转换"

    - name: "dwd_to_dws"
      type: "SQL"
      description: "DWD层到DWS层汇总"
      depends_on: ["ods_to_dwd"]

    - name: "dws_to_ads"
      type: "SQL"
      description: "DWS层到ADS层应用"
      depends_on: ["dwd_to_dws"]

    - name: "data_quality_check"
      type: "SQL"
      description: "数据质量检查"
      depends_on: ["dws_to_ads"]
EOF

echo ""
echo "✅ 项目创建成功!"
echo ""
echo "📁 项目结构:"
find "$PROJECT_DIR" -maxdepth 3 -not -path '*/\.*' -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g' 2>/dev/null || tree -L 3 "$PROJECT_DIR" 2>/dev/null
echo ""
echo "📝 下一步:"
echo "   cd $PROJECT_DIR"
echo "   claude"
echo "   /model-design 开始你的第一个模型设计"
echo ""
