---
name: model-standardize
description: |
  模型标准化 - 对存量数仓资产执行命名/分层/归属标准化，生成旧→新迁移映射表。
  触发词：模型标准化、反向归域、命名规范、表归域、迁移映射、规范整改。
argument: { description: "资产清单（asset_inventory.yaml）或数据库连接", required: true }
agent: general-purpose
allowed-tools: [Read, Grep, Glob, Bash]
---

# 模型标准化

> 对存量资产执行规范化（命名、分层、归属），产出**旧→新迁移映射表**，直接供阶段4（渐进迁移）消费。

## 职责边界

- ✅ **本文件负责**：对**已有表**执行标准化（反向归域、命名整改、生成迁移映射）
- ❌ **不负责**：数据域/总线矩阵/指标体系/分层/SCD 的**标准定义** → 属 modeling-assistant，见 `onedata-methodology.md`、`data-modeling-standards.md`
- ❌ **不负责**：标准化的物理执行（改名/迁数据）→ 见 [migration-playbook.md](migration-playbook.md)

> 本阶段**消费** modeling 规范并应用到存量，不重新教授规范本身。

## 核心方法：反向归域

新数仓建设是"正向"（先划数据域，再建表）；存量重构是"反向"——已有大量无规范表，需反向归类到数据域。

```
业务调研 → 表归类（按业务过程归入数据域）→ 域内整理（命名/粒度统一）→ 评审确认 → 迁移映射
```

### Step 1：业务调研
- 梳理核心业务线与业务过程（交易、用户、商品、流量……）
- 识别每张存量表服务的业务过程

### Step 2：表归域
将每张表归属到一个数据域（交易域/用户域/商品域/流量域/营销域……）：

| 存量表 | 归域依据 | 目标数据域 |
|--------|---------|-----------|
| `order_info` | 服务"下单/支付"过程 | 交易域 |
| `user_base` | 服务"注册/登录"过程 | 用户域 |
| `order_info_ex`（疑似重复） | 与 order_info 同过程 | 交易域（标准化标注"疑似重复"；深度合并由 dup-detection + 迁移处理） |

### Step 3：域内整理
- **命名**：改为 `{layer}_{domain}_{entity}_{granularity}`（如 `order_info` → `dwd_trade_order_detail`）
- **分层**：按 ODS/DWD/DWS/ADS/DIM 归位
- **粒度**：确认每表粒度单一（粒度混乱的拆分）

### Step 4：评审确认
与业务/技术方对齐归域与改名，确认后产出迁移映射表。

## 命名规范化映射规则

| 旧命名问题 | 规则 | 示例 |
|-----------|------|------|
| 缺层级前缀 | 加 `ods/dwd/dws/ads/dim_` | `order` → `dwd_trade_order` |
| 缺数据域 | 加域前缀 | `user_base` → `dwd_user_user` |
| 版本/副本后缀 | 去除 `_v1/_old/_bak` | `dim_user_v1` → `dim_user` |
| 命名风格不一 | 统一 snake_case | `OrderInfo` → `dwd_trade_order` |
| 复数形式 | 统一单数实体 | `orders` → `dwd_trade_order` |

> 完整命名规范（表/字段/分层）见 `modeling-assistant/references/data-modeling-standards.md`。

## 核心产出：迁移映射表（migration_mapping.yaml）

```yaml
# 模型标准化迁移映射表（阶段4 迁移的直接输入）
metadata:
  generated_at: "2026-01-15"
  domain_owner: "data-platform-team"

mappings:
  - old_table: order_info
    new_table: dwd_trade_order_detail
    layer: DWD
    domain: trade
    rename_reason: "缺层级+域前缀；粒度为订单项"
    field_mappings:             # 字段级改名（如有）
      - old: create_time
        new: order_time
        reason: "统一业务时间命名"
    actions:
      - rename                  # 仅改名
      - field_rename
    risk: P2                    # 优先级（来自 impact-analysis）

  - old_table: dim_user_v1
    new_table: dim_user
    layer: DIM
    domain: user
    rename_reason: "版本后缀去除；与 dim_user 合并（dup-detection DUP_002）"
    actions:
      - merge_into              # 合并到标准表
      - create_compat_view      # 旧名建视图兼容
    risk: P1
```

## 标准化检查清单

- [ ] 每张表已归属到一个数据域
- [ ] 表名符合 `{layer}_{domain}_{entity}_{granularity}` 规范
- [ ] 字段名 snake_case，无大小写混用
- [ ] 粒度单一（混杂粒度已拆分）
- [ ] 版本/副本后缀已清理（明显重复标注"疑似"，深度合并留待 dup-detection + 迁移）
- [ ] 迁移映射表经业务/技术评审确认

## 关联

- 规范定义（数据域/分层/命名/SCD）：`modeling-assistant/references/onedata-methodology.md`、`data-modeling-standards.md`
- 重复表识别：[dup-detection.md](dup-detection.md)
- 映射的物理执行（改名/合并/视图）：[migration-playbook.md](migration-playbook.md)
- 命名检查脚本：`scripts/check-naming.sh`
