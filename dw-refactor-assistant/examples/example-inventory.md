# 示例：资产盘点完整流程

## 场景描述

对 AnalyticDB MySQL 数仓进行资产盘点，识别烟囱式开发问题。

---

## Step 1：执行资产扫描

```bash
/asset-inventory
数据源：AnalyticDB MySQL
范围：全库（ods/dwd/dws/ads/dim）
输出格式：YAML + Markdown 报告
```

---

## Step 2：生成资产清单

```yaml
# asset_inventory.yaml
inventory_date: "2024-01-15"
scope: "adb_mysql.production"

summary:
  total_tables: 1250
  total_views: 320
  total_size_gb: 850
  
by_layer:
  ods: { tables: 180, size_gb: 200 }
  dwd: { tables: 350, size_gb: 280 }
  dws: { tables: 420, size_gb: 250 }
  ads: { tables: 300, size_gb: 120 }
  unknown: { tables: 0 }
  
by_domain:
  trade: { tables: 320 }
  user: { tables: 180 }
  product: { tables: 150 }
  traffic: { tables: 280 }
  unknown: { tables: 320 }  # 25% 未归域

top_tables_by_size:
  - name: "ods_order_info"
    size_gb: 45
    domain: "交易域"
    
  - name: "dwd_user_behavior_log"
    size_gb: 35
    domain: "流量域"
    
  - name: "dws_trade_summary"
    size_gb: 28
    domain: "交易域"
```

---

## Step 3：识别问题

```yaml
# issues_report.yaml
generated_at: "2024-01-15"

summary:
  total_issues: 785
  critical: 15
  major: 85
  minor: 685

critical_issues:
  
  # 问题1：跨层依赖
  - code: "C001"
    category: "跨层依赖"
    severity: "critical"
    count: 15
    examples:
      - source: "ads_sales_report"
        target: "ods_order_info"
        layers: "ADS → ODS"
        impact: "影响数据质量，无法验证"
        
      - source: "ads_user_retention"
        target: "dwd_user_profile"
        layers: "ADS → DWD"
        impact: "跳过 DWS 层，逻辑无法复用"
        
  # 问题2：循环依赖
  - code: "C002"
    category: "循环依赖"
    severity: "critical"
    count: 3
    examples:
      - task_a: "task_dwd_order_check"
        task_b: "task_dwd_order_update"
        relation: "A 依赖 B，B 依赖 A"

major_issues:
  
  # 问题3：模型重复
  - code: "M001"
    category: "模型重复"
    severity: "major"
    count: 28
    examples:
      - tables:
          - "dwd_order_detail_1"
          - "dwd_order_detail_2"
          - "dwd_order_detail_v3"
        similarity: "90%"
        impact: "存储重复 50GB，维护成本 3x"
        
      - tables:
          - "dws_trade_summary_1"
          - "dws_trade_summary_daily"
          - "dws_trade_kpi_report"
        similarity: "85%"
        impact: "口径冲突，下游困惑"
        
  # 问题4：未归域
  - code: "M002"
    category: "未归域"
    severity: "major"
    count: 320
    percentage: "25%"
    top_unclassified:
      - "tmp_order_calc"
      - "user_info_backup"
      - "order_detail_test"
      
minor_issues:
  
  # 问题5：命名不规范
  - code: "N001"
    category: "命名不规范"
    count: 450
    examples:
      - "tmp_order_calc"
      - "order_info_v2"
      - "user_info_backup"
      - "dwd_order_old"
      
  # 问题6：缺少负责人
  - code: "N002"
    category: "缺少负责人"
    count: 180
    
  # 问题7：缺少文档
  - code: "N003"
    category: "缺少文档"
    count: 520
```

---

## Step 4：评估优先级

```yaml
# priority_matrix.yaml

priorities:
  
  P0_critical:
    items:
      - issue: "跨层依赖 ADS→ODS"
        score: 20
        reason: "影响核心报表，数据质量风险高"
        action: "立即重构依赖链路"
        
      - issue: "3个循环依赖"
        score: 15
        reason: "任务无法正常调度"
        action: "立即解除循环"
        
  P1_high:
    items:
      - issue: "28个模型重复"
        score: 12
        reason: "存储浪费 50GB，维护成本高"
        action: "1-2周内合并"
        
      - issue: "320张表未归域"
        score: 10
        reason: "无法统一管理"
        action: "1-2周内归域"
        
  P2_medium:
    items:
      - issue: "450个命名不规范"
        score: 6
        reason: "影响可读性和治理"
        action: "1-2月内整改"
        
      - issue: "180个缺少负责人"
        score: 5
        reason: "责任不清晰"
        action: "1月内分配负责人"
        
  P3_low:
    items:
      - issue: "520个缺少文档"
        score: 2
        reason: "知识传承受阻"
        action: "长期补充文档"
```

---

## Step 5：生成盘点报告

```markdown
# 数仓资产盘点报告

**盘点日期**: 2024-01-15
**盘点范围**: AnalyticDB MySQL 全库

## 1. 盘点概况

| 指标 | 数值 |
|------|------|
| 总表数 | 1250 |
| 总存储 | 850 GB |
| 问题总数 | 785 |
| 严重问题 | 15 |

## 2. 资产分布

### 按分层分布
| 层级 | 表数 | 占比 | 存储 |
|------|------|------|------|
| ODS | 180 | 14% | 200 GB |
| DWD | 350 | 28% | 280 GB |
| DWS | 420 | 34% | 250 GB |
| ADS | 300 | 24% | 120 GB |

### 按数据域分布
| 数据域 | 表数 | 占比 |
|--------|------|------|
| 交易域 | 320 | 26% |
| 用户域 | 180 | 14% |
| 商品域 | 150 | 12% |
| 流量域 | 280 | 22% |
| **未归域** | **320** | **25%** |

## 3. 问题统计

| 问题类型 | 严重 | 重要 | 一般 | 合计 |
|----------|------|------|------|------|
| 跨层依赖 | 15 | - | - | 15 |
| 模型重复 | - | 28 | - | 28 |
| 未归域 | - | 320 | - | 320 |
| 命名不规范 | - | - | 450 | 450 |
| 缺少负责人 | - | - | 180 | 180 |

## 4. Top 10 问题

| 排名 | 问题 | 影响 | 优先级 |
|------|------|------|--------|
| 1 | ADS 直接依赖 ODS | 15个报表数据质量风险 | P0 |
| 2 | 3个循环依赖 | 任务无法调度 | P0 |
| 3 | 28个模型重复 | 存储50GB，维护3x | P1 |
| 4 | 320张表未归域 | 无法统一管理 | P1 |
| 5 | 450个命名不规范 | 可读性差 | P2 |

## 5. 建议与下一步

### 立即处理（P0）
1. 解除 ADS→ODS 跨层依赖，建立正确链路
2. 解除 3 个循环依赖

### 1-2周内处理（P1）
1. 合并 28 个重复模型
2. 为 320 张未归域表分配数据域

### 1-2月内处理（P2）
1. 整改 450 个命名不规范表
2. 分配 180 个表负责人

### 长期优化（P3）
1. 补充 520 个表文档
2. 建立持续治理机制
```

---

## Step 6：启动重构

```bash
# 基于盘点结果，启动重构
/dw-refactor-assistant 端到端重构：解决跨层依赖问题
```

**输出**：
- 重构计划（渐进式迁移）
- 双跑方案
- 回滚预案
```