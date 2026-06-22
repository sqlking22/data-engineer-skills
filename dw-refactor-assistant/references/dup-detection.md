---
name: dup-detection
description: |
  重复模型检测 - 识别数仓中重复/相似的表与逻辑，输出合并建议清单。
  触发词：重复模型、模型重复、相似表、烟囱式开发、合并模型、重复逻辑。
argument: { description: "数据库连接串 或 资产清单文件（asset_inventory.yaml）", required: true }
agent: general-purpose
allowed-tools: [Read, Grep, Glob, Bash]
---

# 重复模型检测

> 识别烟囱式开发遗留的重复/相似模型，输出合并建议清单，供阶段2（标准化）与阶段4（迁移）消费。

## 职责边界

- ✅ **本文件负责**：检测重复/相似模型、计算相似度、产出合并建议清单
- ❌ **不负责**：合并的物理执行（建新表/迁数据/视图兼容/下游切换）→ 见 [migration-playbook.md](migration-playbook.md)
- ❌ **不负责**：合并后新模型的规范定义（命名/分层/SCD）→ 见 modeling-assistant 的 `data-modeling-standards.md`

## 检测维度

| 维度 | 检测信号 | 严重度 |
|------|---------|--------|
| **表名相似** | 去除版本/副本后缀后基础名相同（`xxx_v1`、`xxx_old`、`xxx_bak`） | 🟡 |
| **结构相同** | 字段集合完全一致（字段哈希相同） | 🔴 强烈建议合并 |
| **业务逻辑重复** | 不同表产出相同指标/相同粒度（需结合 SQL 解析） | 🔴 |
| **指标口径重复** | 多处定义同一原子指标（需结合指标字典） | 🟡 |

## 检测方法

### 方法1：表名相似性

去除版本/副本后缀后比较基础名。后缀模式：`_v[0-9]+`、`_[0-9]+`、`_old`、`_new`、`_bak`、`_backup`、`_copy`。

```sql
-- 取全部表名，按基础名分组找同源表
SELECT TABLE_NAME
FROM information_schema.tables
WHERE TABLE_SCHEMA = '$DB_NAME'
ORDER BY TABLE_NAME;
-- 脚本中用 sed 去后缀 + grep 同前缀，详见 detect-duplicates.sh
```

### 方法2：字段结构哈希

将每个表的字段名按序拼接成哈希，哈希相同即结构完全一致：

```sql
-- 取每表字段序列
SELECT TABLE_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION) AS field_hash
FROM information_schema.columns
WHERE TABLE_SCHEMA = '$DB_NAME'
GROUP BY TABLE_NAME;
-- field_hash 相同的表 = 结构完全重复
```

### 方法3：业务逻辑重复（SQL 解析）

对每张表的产出 SQL 做字段级血缘解析，若两张表的字段血缘来源与转换逻辑高度重合，判定为逻辑重复。血缘解析方法见 [lineage-analysis-guide.md](lineage-analysis-guide.md)。

## 常见重复模式

| 模式 | 典型表现 | 根因 |
|------|---------|------|
| 版本迭代遗留 | `xxx_v1`、`xxx_v2`、`xxx_v3` 并存 | 新版上线未下线旧版 |
| 各自开发 | `order_info`、`orders`、`order_data` | 不同人重复造轮子 |
| 命名不一致 | `user_dim`、`dim_user`、`dim_users` | 缺统一命名规范 |
| 临时表残留 | `tmp_order_202401`、`tmp_user_202402` | 临时表未清理 |

## 输出：重复清单（dup_report.yaml）

```yaml
# 重复模型检测报告
metadata:
  generated_at: "2026-01-15 10:30:00"
  database: "bigdata"
  detection_method: ["name_similarity", "structure_hash", "lineage"]

duplicate_groups:
  - group_id: DUP_001
    severity: 🔴                  # 结构完全相同
    type: structure_identical
    tables: [dwd_order_detail_1, dwd_order_detail_2]
    evidence: "字段集合完全一致（32 列）"
    suggestion: "强烈建议合并，保留其一，另一改视图兼容"
    downstream_impact: "dwd_order_detail_2 有 3 个下游任务"  # 来自 impact-analysis

  - group_id: DUP_002
    severity: 🟡                  # 仅表名相似
    type: name_similarity
    tables: [dim_user, dim_user_v1, dim_user_old]
    evidence: "基础名 dim_user 相同"
    suggestion: "人工评估：确认版本迭代是否仍需旧版"

summary:
  total_groups: 12
  structure_identical: 4          # 优先合并
  name_similarity: 6
  logic_duplicate: 2
```

## 合并策略（决策表）

| 情况 | 处理策略 |
|------|---------|
| 完全重复 + 无下游 | 直接删除冗余表 |
| 完全重复 + 有下游 | 保留标准版，其余改为**视图兼容**（见 migration-playbook 视图兼容阶段） |
| 业务口径不同 | 保留，但明确命名差异（加业务域前缀） |
| 版本迭代遗留 | 评估旧版是否仍被使用，无下游则下线 |

> **合并执行**（建新表/迁数据/视图/下游切换/旧表下线）的完整步骤见 [migration-playbook.md](migration-playbook.md)，本文件只到"建议清单"。

## 合并前必做

- [ ] 跑 `/impact-analysis` 确认每张重复表的下游依赖
- [ ] 核对重复表的数据是否一致（抽样对比）
- [ ] 确认是否有不同业务口径（避免误合并）

## 关联

- 自动化检测脚本：`scripts/detect-duplicates.sh`（表名相似 + 结构哈希 + 报告生成）
- 血缘/影响分析：[lineage-analysis-guide.md](lineage-analysis-guide.md)
- 合并执行：[migration-playbook.md](migration-playbook.md)
- 新模型命名规范：`modeling-assistant/references/data-modeling-standards.md`
