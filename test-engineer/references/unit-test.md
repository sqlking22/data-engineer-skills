---
name: unit-test
description: |
  单元测试生成器 - 为单表/模型生成字段级单元测试（代理键、外键、非空、枚举、计算字段）。
  触发词：单元测试、字段校验、代理键唯一性、模型验证、数据单元测试。
argument: { description: "表名 或 modeling_package.yaml / dq_package.yaml", required: true }
agent: general-purpose
allowed-tools: [Read, Grep, Glob, Edit, Write, Bash]
---

# 单元测试生成器

为单张表生成字段级单元测试用例，验证模型最基本约束。单元测试位于测试金字塔底层（快、隔离、量大）。

## 工作流

1. **解析测试对象** — 读取表结构 / modeling_package / dq_package
2. **识别测试维度** — 按字段类型与约束自动匹配测试类型
3. **生成用例** — 每条约束产出一条断言用例（含失败信息）
4. **输出** — `tests/unit/test_cases_<table>.yaml`

## 测试类型

| 类型 | 触发条件 | 断言 |
|------|---------|------|
| 代理键唯一性 | 主键/代理键字段 | `COUNT(*) = COUNT(DISTINCT sk)` |
| 代理键非空 | 主键字段 | `sk IS NOT NULL` |
| 外键有效性 | _sk/_id 外键字段 | 外键值在维度表中存在 |
| 字段非空 | NOT NULL 字段 / 业务必填 | `col IS NOT NULL` |
| 枚举合法 | status/type 等枚举字段 | `col IN (...)` |
| 计算字段正确 | 派生字段（如金额=单价×数量） | 重算对比 |
| 数据类型一致 | 数值/日期字段 | 类型校验 |

## 输入

```
/unit-test 表: fct_order_items
/unit-test --from-dq          # 基于 dq_package 的规则生成
/unit-test --from-model       # 基于 modeling_package 的 schema 生成
```

## 输出（test_cases.yaml）

```yaml
# tests/unit/test_cases_fct_order_items.yaml
table: fct_order_items
test_suite: unit
generated_at: "2026-01-15"

cases:
  - id: UT_001
    name: "代理键唯一性"
    type: uniqueness
    column: order_item_sk
    sql: "SELECT COUNT(*) - COUNT(DISTINCT order_item_sk) AS dup_cnt FROM fct_order_items"
    assert: "dup_cnt = 0"
    severity: error
    fail_msg: "发现 {dup_cnt} 个重复代理键"

  - id: UT_002
    name: "用户外键有效性"
    type: referential_integrity
    column: user_sk
    sql: |
      SELECT COUNT(*) AS orphan_cnt
      FROM fct_order_items f
      LEFT JOIN dim_user u ON f.user_sk = u.user_sk AND u.is_current = TRUE
      WHERE u.user_sk IS NULL
    assert: "orphan_cnt = 0"
    severity: error
    fail_msg: "{orphan_cnt} 条记录的用户外键在 dim_user 中找不到"

  - id: UT_003
    name: "金额非负"
    type: range
    column: amount
    sql: "SELECT COUNT(*) AS neg_cnt FROM fct_order_items WHERE amount < 0"
    assert: "neg_cnt = 0"
    severity: warning
```

## 断言规范

- 每条用例必须有 `sql` + `assert` + `severity`（error/warning）
- `fail_msg` 含具体数值，失败时能定位问题规模
- 优先使用聚合断言（COUNT 比较），避免逐行断言（性能差）
- 详见 [test-standards.md](test-standards.md) 断言规范章节

## 关联

- 规范：[test-standards.md](test-standards.md)（断言库、命名、覆盖率）
- 避坑：[best-practices.md](best-practices.md)
- 上游：dq-assistant（`--from-dq`）、modeling-assistant（`--from-model`）
