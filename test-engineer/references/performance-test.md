---
name: performance-test
description: |
  性能测试生成器 - 验证查询性能是否达标（P50/P95、并发、扫描行数、回归对比）。
  触发词：性能测试、慢查询、P95、性能基线、查询性能、并发测试。
argument: { description: "测试目标（查询/表）+ 基准要求 或 sql_package.yaml", required: true }
agent: general-purpose
allowed-tools: [Read, Grep, Glob, Edit, Write, Bash]
---

# 性能测试生成器

验证查询/ETL 性能是否满足基线，并支持回归对比（性能不退化）。位于测试金字塔顶层（量少、成本高）。

## 工作流

1. **识别测试目标** — 解析目标查询/表/ETL 任务
2. **设定性能基线** — P50/P95/P99、并发数、扫描行数上限
3. **生成压测脚本** — 串行 + 并发执行，采集耗时/资源
4. **回归对比** — 与历史基线对比，检测性能退化
5. **输出** — `tests/performance/perf_report_<target>.yaml`

## 性能指标

| 指标 | 说明 | 采集方式 |
|------|------|---------|
| P50 / P95 / P99 | 响应时间分位数 | 多次执行取分位 |
| 并发吞吐 | 并发下 QPS / 平均耗时 | 并发压测 |
| 扫描行数 | 数据扫描量 | EXPLAIN / 执行计划 |
| 资源占用 | CPU / 内存 | 监控采集 |
| 超时率 | 超过 SLA 的比例 | 统计超时次数 |

## 输入

```
/performance-test 目标: ADS层销售日报查询
基准:
- P50 < 2秒, P95 < 5秒
- 并发10用户

/performance-test --from-sql    # 基于 sql_package 的查询压测
```

## 输出（perf_report.yaml）

```yaml
# tests/performance/perf_report_ads_sales_daily.yaml
target: "ADS 销售日报查询"
test_suite: performance
baseline:
  p50_ms: 2000
  p95_ms: 5000
  concurrency: 10
  timeout_ms: 10000

execution:
  runs: 100                    # 串行执行 100 次
  concurrency_runs: 10         # 并发 10 用户

results:
  p50_ms: 1850
  p95_ms: 4200
  p99_ms: 6100
  timeout_rate: 0.0
  avg_scan_rows: 1250000

verdict: 🟢 pass               # P50/P95 达标
regression:
  baseline_p95: 4000           # 上次基线
  current_p95: 4200
  delta: "+5%"
  degraded: false              # 退化 < 10% 视为正常波动

cases:
  - id: PT_001
    name: "P95 响应时间"
    assert: "p95_ms <= 5000"
    actual: 4200
    pass: true
  - id: PT_002
    name: "并发吞吐（10 并发下平均耗时）"
    assert: "concurrent_avg_ms <= 8000"
    actual: 7100
    pass: true
```

## 性能基线规范

| 场景 | 建议 SLA |
|------|---------|
| ADS 报表查询（交互） | P95 < 5s |
| DWS 宽表查询 | P95 < 10s |
| DWD 明细查询（带分区） | P95 < 30s |
| ETL 任务（单任务） | 视数据量，通常 < 30min |
| 回归退化阈值 | P95 退化 > 10% 报警，> 30% 阻断 |

> 基线一旦设定不要随意改（见 best-practices 踩坑#3：性能基线一直更新导致漏掉回归）。

## 要点

- **必须带分区裁剪**：压测查询带 `pt` 过滤，模拟真实生产写法（不带分区 = 全表扫描，无意义）
- **采样真实数据量**：用生产量级数据压测，小数据量压不出问题
- **回归基线固化**：每次性能测试结果存档，作为下次对比基线

## 关联

- 规范：[test-standards.md](test-standards.md) 性能基准章节
- 避坑：[best-practices.md](best-practices.md)（性能只测一次、基线漂移反例）
- 上游：sql-assistant（`--from-sql`，压测目标查询）
- 执行计划诊断：`sql-assistant/references/sql-explain.md`
