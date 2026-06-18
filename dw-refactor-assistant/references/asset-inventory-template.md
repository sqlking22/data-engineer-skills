---
name: asset-inventory-template
description: |
  数仓资产盘点模板 - 标准化的盘点检查清单和输出格式。
  触发词：资产盘点模板、盘点检查清单、资产清单格式。
---

# 数仓资产盘点模板

## 1. 盘点清单表头

### 1.1 表资产清单

```yaml
# table_inventory.yaml
inventory_metadata:
  project: "{项目名称}"
  inventory_date: "{盘点日期}"
  inventory_by: "{盘点人}"
  scope: "{盘点范围：数据库/全库}"
  data_source: "{数据源：AnalyticDB MySQL/MaxCompute}"

summary:
  total_tables: {总表数}
  total_views: {总视图数}
  total_size_gb: {总存储大小GB}
  total_rows: {总行数}
  
by_layer:
  ods: { tables: N, size_gb: N }
  dwd: { tables: N, size_gb: N }
  dws: { tables: N, size_gb: N }
  ads: { tables: N, size_gb: N }
  dim: { tables: N, size_gb: N }
  unknown: { tables: N, size_gb: N }  # 未分层

by_domain:
  trade: { tables: N, size_gb: N }
  user: { tables: N, size_gb: N }
  product: { tables: N, size_gb: N }
  traffic: { tables: N, size_gb: N }
  unknown: { tables: N, size_gb: N }  # 未归域

tables:
  - schema: "{数据库/Schema}"
    name: "{表名}"
    type: "{TABLE/VIEW}"
    layer: "{ODS/DWD/DWS/ADS/DIM/UNKNOWN}"
    domain: "{交易域/用户域/.../UNKNOWN}"
    
    # 存储信息
    size_gb: {存储大小GB}
    row_count: {行数}
    partition_count: {分区数}
    
    # 时间信息
    create_time: "{创建时间}"
    last_modified: "{最后修改时间}"
    last_accessed: "{最后访问时间}"
    
    # 责任信息
    owner: "{负责人}"
    team: "{所属团队}"
    
    # 文档信息
    has_documentation: {true/false}
    has_comment: {true/false}
    
    # 使用信息
    has_downstream: {true/false}
    downstream_count: {下游消费数}
    is_orphan: {true/false}
    
    # 问题标记
    issues:
      - code: "{问题代码}"
        severity: "{严重/重要/一般}"
        description: "{问题描述}"
```

### 1.2 任务资产清单

```yaml
# task_inventory.yaml
inventory_metadata:
  project: "{项目名称}"
  inventory_date: "{盘点日期}"
  scheduler: "{调度系统：DataWorks/DolphinScheduler}"

summary:
  total_tasks: {总任务数}
  active_tasks: {活跃任务数}
  inactive_tasks: {非活跃任务数}
  
by_type:
  data_sync: {同步任务数}
  data_transform: {转换任务数}
  data_quality: {质量检查任务数}
  
tasks:
  - task_id: "{任务ID}"
    task_name: "{任务名称}"
    task_type: "{任务类型}"
    schedule: "{调度周期：daily/hourly/...}"
    
    # 依赖信息
    upstream_tasks: ["{上游任务列表}"]
    downstream_tasks: ["{下游任务列表}"]
    dependency_depth: {依赖深度}
    
    # 源表和目标表
    source_tables: ["{源表列表}"]
    target_tables: ["{目标表列表}"]
    
    # 运行信息
    avg_duration: "{平均运行时长}"
    success_rate: "{成功率}"
    last_run: "{最后运行时间}"
    
    # 责任信息
    owner: "{负责人}"
    team: "{所属团队}"
    
    # 问题标记
    issues:
      - code: "{问题代码}"
        description: "{问题描述}"
```

### 1.3 报表资产清单

```yaml
# report_inventory.yaml
inventory_metadata:
  project: "{项目名称}"
  inventory_date: "{盘点日期}"

summary:
  total_reports: {总报表数}
  by_type:
    bi_dashboard: {BI仪表盘数}
    scheduled_report: {定期报表数}
    api_service: {API服务数}

reports:
  - report_id: "{报表ID}"
    report_name: "{报表名称}"
    report_type: "{BI/REPORT/API}"
    
    # 数据源
    source_tables: ["{数据源表列表}"]
    
    # 使用信息
    users: ["{使用用户/部门}"]
    access_frequency: "{访问频率：高/中/低}"
    
    # 责任信息
    owner: "{负责人}"
    
    # 业务信息
    business_domain: "{业务域}"
    importance: "{重要程度：核心/重要/一般}"
```

---

## 2. 问题检查清单

### 2.1 结构问题检查

```markdown
## 结构问题检查清单

### 分层问题
- [ ] 是否存在未分层的表？
  - 检查方法：按表名前缀（ods_/dwd_/dws_/ads_/dim_）归类
  - 统计未匹配前缀的表数量
  
- [ ] 是否存在跨层依赖？
  - 检查方法：分析任务SQL，检查源表和目标表的层级差距
  - 记录：ADS → ODS、ADS → DWD 等违规依赖

### 数据域问题
- [ ] 是否存在未归域的表？
  - 检查方法：按业务用途归类，识别无法归类的表
  - 统计：未归域表数量及占比

### 重复问题
- [ ] 是否存在重复模型？
  - 检查方法：
    1. 按业务主题分组
    2. 分析同主题下的多个表
    3. 比较字段结构和SQL逻辑
  - 记录：重复表清单及相似度
```

### 2.2 规范问题检查

```markdown
## 规范问题检查清单

### 命名规范
- [ ] 表名是否符合 {layer}_{domain}_{entity} 格式？
  - 违规示例：tmp_order, order_info_v2, order_copy
  
- [ ] 字段名是否使用 snake_case？
  - 违规示例：orderID, TotalAmount
  
- [ ] 字段名是否含义清晰？
  - 违规示例：col1, col2, tmp_field

### 文档规范
- [ ] 表是否有注释？
- [ ] 字段是否有注释？
- [ ] 是否有数据字典？

### 责任规范
- [ ] 表是否有负责人？
- [ ] 任务是否有负责人？
- [ ] 报表是否有负责人？
```

### 2.3 质量问题检查

```markdown
## 质量问题检查清单

### 数据新鲜度
- [ ] 核心表更新是否及时？
  - 检查方法：比较 last_modified 与预期更新周期
  
### 数据完整性
- [ ] 是否存在大量空值字段？
  - 检查方法：统计字段空值率

### 数据一致性
- [ ] 同一指标是否有多个口径？
  - 检查方法：分析不同表中的同名指标定义

### 孤儿数据
- [ ] 是否存在无下游消费的表？
  - 检查方法：分析血缘关系，识别无下游的表
  
- [ ] 是否存在长期未更新的表？
  - 检查方法：检查 last_modified 超过 N 天的表
```

---

## 3. 盘点执行脚本

### 3.1 表资产扫描脚本

```sql
-- AnalyticDB MySQL 表资产扫描
SELECT 
    table_schema AS schema_name,
    table_name,
    table_type,
    table_rows,
    ROUND(data_length / 1024 / 1024 / 1024, 2) AS size_gb,
    table_comment,
    create_time,
    update_time
FROM information_schema.tables
WHERE table_schema NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
ORDER BY table_schema, table_name;

-- MaxCompute 表资产扫描（通过 Information Schema）
SELECT 
    table_schema,
    table_name,
    table_type,
    comment,
    create_time,
    last_modified_time,
    -- MaxCompute 特有字段
    lifecycle,
    is_archived,
    size
FROM information_schema.tables
ORDER BY table_schema, table_name;
```

### 3.2 分区统计脚本

```sql
-- 分区统计（ADB MySQL）
SELECT 
    table_schema,
    table_name,
    COUNT(*) AS partition_count,
    MIN(partition_name) AS earliest_partition,
    MAX(partition_name) AS latest_partition
FROM information_schema.partitions
WHERE table_schema NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
GROUP BY table_schema, table_name
ORDER BY table_schema, table_name;

-- 分区统计（MaxCompute）
SELECT 
    table_schema,
    table_name,
    COUNT(*) AS partition_count,
    MIN(partition_name) AS earliest_partition,
    MAX(partition_name) AS latest_partition
FROM information_schema.partitions
GROUP BY table_schema, table_name;
```

---

## 4. 问题报告模板

```yaml
# issues_report.yaml
report_metadata:
  generated_at: "{生成时间}"
  inventory_date: "{盘点日期}"
  scope: "{盘点范围}"

summary:
  total_issues: {问题总数}
  critical: {严重问题数}
  major: {重要问题数}
  minor: {一般问题数}

issues_by_category:
  
  structure_issues:
    - code: "S001"
      category: "跨层依赖"
      severity: "critical"
      count: {数量}
      impact: "{影响范围}"
      examples:
        - table: "{表名}"
          from_layer: "ADS"
          to_layer: "ODS"
          
    - code: "S002"
      category: "模型重复"
      severity: "major"
      count: {数量}
      examples:
        - tables: ["dwd_order_1", "dwd_order_2", "dwd_order_3"]
          similarity: "85%"
          
    - code: "S003"
      category: "未归域"
      severity: "major"
      count: {数量}
      
  naming_issues:
    - code: "N001"
      category: "命名不规范"
      severity: "minor"
      count: {数量}
      examples:
        - table: "tmp_order_calc"
          suggestion: "应删除或重命名"
          
  documentation_issues:
    - code: "D001"
      category: "缺少文档"
      severity: "minor"
      count: {数量}
      
  responsibility_issues:
    - code: "R001"
      category: "缺少负责人"
      severity: "minor"
      count: {数量}
```

---

## 5. 优先级评估模板

```yaml
# priority_matrix.yaml
evaluation_date: "{评估日期}"

priorities:
  
  P0_critical:
    description: "立即处理"
    criteria: "总分 ≥ 15 或影响核心业务"
    items:
      - issue_id: "{问题ID}"
        summary: "{问题描述}"
        impact_score: {影响分数}
        urgency_score: {紧急分数}
        total_score: {总分}
        reason: "{为何优先}"
        
  P1_high:
    description: "1-2周内处理"
    criteria: "总分 10-15"
    items:
      - issue_id: "{问题ID}"
        summary: "{问题描述}"
        
  P2_medium:
    description: "1-2月内处理"
    criteria: "总分 5-10"
    items: []
    
  P3_low:
    description: "长期优化"
    criteria: "总分 < 5"
    items: []
```

---

## 6. 盘点报告输出

```markdown
# 数仓资产盘点报告

## 1. 盘点概况

| 指标 | 数值 |
|------|------|
| 盘点日期 | {日期} |
| 盘点范围 | {范围} |
| 总表数 | {数量} |
| 总存储 | {大小} |
| 问题总数 | {数量} |

## 2. 资产分布

### 按分层分布
| 层级 | 表数 | 占比 | 存储 |
|------|------|------|------|
| ODS | N | N% | N GB |
| DWD | N | N% | N GB |
| DWS | N | N% | N GB |
| ADS | N | N% | N GB |
| 未分层 | N | N% | N GB |

### 按数据域分布
| 数据域 | 表数 | 占比 |
|--------|------|------|
| 交易域 | N | N% |
| 用户域 | N | N% |
| 未归域 | N | N% |

## 3. 问题统计

| 问题类型 | 严重 | 重要 | 一般 | 合计 |
|----------|------|------|------|------|
| 结构问题 | N | N | N | N |
| 规范问题 | N | N | N | N |
| 文档问题 | N | N | N | N |
| 责任问题 | N | N | N | N |

## 4. Top 10 问题

| 排名 | 问题 | 影响 | 优先级 |
|------|------|------|--------|
| 1 | {问题} | {影响} | P0 |
| ... | ... | ... | ... |

## 5. 建议与下一步

1. {建议1}
2. {建议2}
3. {建议3}
```
