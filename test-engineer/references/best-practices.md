---
name: test-engineer-best-practices
description: |
  数据测试最佳实践 - 团队经验沉淀，包含 Fixture 策略、性能基准、CI/CD 集成。
  触发词：数据测试、最佳实践、避坑指南、测试金字塔、Fixture、pytest、性能测试、CI/CD。
---

# 数据测试最佳实践

> 本文沉淀团队在数据测试方面的实战经验，配套 [SKILL.md](../SKILL.md) 一起使用。
> 详细规范见 [test-standards.md](test-standards.md)。

## 1. 核心原则速查

| # | 核心原则 | 说明 |
|---|---------|------|
| 1 | **测试金字塔** | 单元测试 > 集成测试 > UI 测试，按比例分布 |
| 2 | **Fixture 独立** | 每个测试用独立数据集，避免相互干扰 |
| 3 | **断言信息丰富** | 失败时能快速定位问题，包含实际值与期望值 |
| 4 | **容忍度合理** | 根据业务场景设置合理容忍度，避免误报 |
| 5 | **性能基线** | 关键查询有性能基线，回归时自动对比 |
| 6 | **数据隔离** | 测试数据不污染生产，使用独立 schema |
| 7 | **CI 集成** | 测试纳入 CI/CD，每次提交自动跑 |
| 8 | **覆盖率监控** | 关键表覆盖率 > 90%，跟踪趋势 |

## 2. 反模式与避坑指南

### ❌ 反例 1：测试金字塔倒置

```python
# 错误：几乎全是 UI 测试，单元测试很少
def test_full_dashboard():  # 80% 是这类
    """测试整个仪表盘"""
    login()
    navigate_to_dashboard()
    set_filters()
    verify_charts()
    verify_tables()
    export_report()
    # 测试时间 5 分钟，调试困难

def test_one_metric():  # 只有 20% 单元测试
    """测试单个指标计算"""
    assert calculate_gmv(orders) == expected_gmv
```

✅ 正例：

```python
# 正确：金字塔结构
# 60% 单元测试（快、隔离、易调试）
def test_user_level_scd2_change():
    """用户等级变化应正确生成新版本"""
    user = create_user(user_id=1, level='A')
    user.update(level='B')
    history = get_user_history(user_id=1)
    assert len(history) == 2
    assert history[0].level == 'A' and history[0].is_current == False
    assert history[1].level == 'B' and history[1].is_current == True

# 25% 集成测试（验证跨组件）
def test_dwd_to_dws_aggregation():
    """DWD 聚合到 DWS 的正确性"""
    seed_dwd_data([...])
    run_dws_etl()
    result = query_dws('pay_amount_1d')
    expected = sum_expected_from_dwd
    assert abs(result - expected) / expected < 0.001

# 10% 接口/契约测试
def test_dws_schema_contract():
    """DWS 表结构契约"""
    schema = get_table_schema('dws_trade_user_1d')
    assert 'user_sk' in schema
    assert 'pay_amount_1d' in schema

# 5% E2E/UI 测试（少量关键路径）
def test_sales_report_loads():
    """销售日报可正常加载"""
    response = api.get('/reports/sales/daily')
    assert response.status_code == 200
```

💡 **为什么**：
- UI 测试慢、脆弱、难调试
- 单元测试快、隔离、易定位问题
- 倒置的金字塔维护成本高，问题难定位

---

### ❌ 反例 2：测试间相互依赖

```python
# 错误：测试间共享数据，顺序敏感
def test_create_user():
    global user_id_counter
    user_id_counter += 1
    create_user(user_id=user_id_counter)  # 依赖全局计数器

def test_update_user():
    # 隐式依赖 test_create_user 先跑
    user = get_user(user_id=1)  # 假设有 ID=1 的用户
    user.update(level='B')
    # 如果 test_create_user 没跑，这个测试会失败
```

✅ 正例：

```python
# 正确：每个测试独立创建数据
@pytest.fixture
def sample_user():
    """每个测试独立的用户数据"""
    user = create_user(
        user_id=random.randint(10000, 99999),
        username=f"test_{uuid.uuid4().hex[:8]}",
        level='A'
    )
    yield user
    # 清理
    cleanup_user(user.user_id)

def test_update_user_level(sample_user):
    """使用 fixture 创建的独立用户"""
    sample_user.update(level='B')
    history = get_user_history(sample_user.user_id)
    assert len(history) == 2

def test_delete_user(sample_user):
    """使用同一 fixture，测试间不互相影响"""
    sample_user.delete()
    assert get_user(sample_user.user_id) is None
```

💡 **为什么**：
- 测试间共享数据导致一个测试失败影响其他测试
- 难调试（看不出是哪个测试创建的数据）
- 并行运行时会冲突

---

### ❌ 反例 3：断言信息不充分

```python
# 错误：断言失败时不知道实际值
def test_gmv_calculation():
    result = calculate_gmv(orders)
    assert result == 1500000  # 失败时只看到 False

def test_dws_amount():
    assert dws_amount > 1000000  # 失败时不知道实际是多少
```

✅ 正例：

```python
# 正确：断言包含实际值、期望值、差异
def test_gmv_calculation():
    result = calculate_gmv(orders)
    expected = 1500000
    assert result == expected, \
        f"GMV 计算错误: 实际={result}, 期望={expected}, 差异={result - expected}"

def test_dws_amount():
    actual = dws_amount
    expected = 1000000
    diff_rate = abs(actual - expected) / expected
    assert diff_rate < 0.001, \
        f"DWS 金额异常: 实际={actual}, 期望={expected}, 差异率={diff_rate:.4%}"
```

💡 **为什么**：
- 失败时无法定位问题（不知道实际值）
- 调试时还要重新跑 + 打印值
- 充分的错误信息能节省 50% 调试时间

---

### ❌ 反例 4：容忍度一刀切

```python
# 错误：所有数值对比都用 0.1% 容忍度
def test_payment_amount():
    assert abs(actual - expected) / expected < 0.001  # 太严
    
def test_user_count():
    assert abs(actual - expected) / expected < 0.001  # 太严
```

✅ 正例：

```python
# 正确：根据业务场景设置不同容忍度

# 整数精确匹配（订单数、用户数）
def test_order_count():
    assert actual == expected, "订单数应该精确匹配"

# 金额可以有小数误差（浮点运算）
def test_gmv_amount():
    diff = abs(actual - expected)
    # 金额 > 1 万元时，绝对差异 < 0.01 元
    if expected > 10000:
        assert diff < 0.01
    else:
        # 金额 < 1 万元时，相对差异 < 0.1%
        assert diff / expected < 0.001

# 比例类指标允许较大差异
def test_conversion_rate():
    diff_rate = abs(actual - expected)
    assert diff_rate < 0.01, f"转化率差异 {diff_rate:.2%} 超过 1%"

# 时间类指标使用绝对误差
def test_data_freshness():
    assert (now - last_update) < timedelta(hours=1), \
        f"数据陈旧: 最后更新时间 {last_update}"
```

💡 **为什么**：
- 一刀切要么误报要么漏报
- 整数/浮点/比例/时间应采用不同容忍度
- 业务场景决定容忍度合理性

---

### ❌ 反例 5：硬编码测试数据

```python
# 错误：硬编码测试数据，难以维护
def test_user_count():
    expected = 1000000  # 这个数字怎么来的？
    actual = query("SELECT COUNT(*) FROM users")
    assert actual == expected  # 数据变了测试就挂

# 错误：硬编码 ID
def test_user_profile():
    user = get_user(user_id=12345)  # 这个 ID 在测试环境不存在
    assert user.username == "expected_name"
```

✅ 正例：

```python
# 正确：基于实际数据计算期望值
def test_user_count():
    # 先查询基线
    baseline = query("SELECT COUNT(*) FROM users WHERE register_date < CURRENT_DATE")
    # 当天新增
    new_today = query("SELECT COUNT(*) FROM new_users_today")
    # 期望值 = 基线 + 新增
    expected = baseline + new_today
    actual = query("SELECT COUNT(*) FROM users")
    assert abs(actual - expected) <= 1, f"差异 {actual - expected} 超过 1"

# 正确：使用 Fixture 动态创建
@pytest.fixture
def test_user():
    """动态创建测试用户"""
    user_id = create_user(username=f"test_{uuid.uuid4().hex[:8]}")
    yield user_id
    delete_user(user_id)

def test_user_profile(test_user):
    user = get_user(user_id=test_user)  # 用动态生成的 ID
    assert user is not None
```

💡 **为什么**：
- 硬编码数据与实际环境脱节
- 测试环境数据变化时测试失败
- 动态数据让测试更稳定

---

### ❌ 反例 6：性能测试只测一次

```python
# 错误：只测一次就当作基线
def test_query_performance():
    start = time.time()
    result = execute_query(SQL)
    duration = time.time() - start
    assert duration < 5  # 5 秒就行？
    # 第一次跑就当性能基线，没有持续监控
```

✅ 正例：

```python
# 正确：多轮测试 + 历史基线对比
def test_query_performance_with_baseline():
    """性能测试 - 多轮 + 基线对比"""
    # 1. 预热（首次执行可能较慢）
    execute_query(SQL)
    
    # 2. 多轮测试
    durations = []
    for _ in range(3):
        start = time.time()
        execute_query(SQL)
        durations.append(time.time() - start)
    
    # 3. 报告指标
    p50 = sorted(durations)[len(durations) // 2]
    p95 = sorted(durations)[int(len(durations) * 0.95)]
    print(f"P50: {p50:.2f}s, P95: {p95:.2f}s")
    
    # 4. 与历史基线对比
    baseline = get_baseline('query_xyz')
    p95_baseline = baseline['p95']
    
    # 5. 断言：当前性能不能比基线慢 50%
    assert p95 < p95_baseline * 1.5, \
        f"P95 {p95:.2f}s 超过基线 {p95_baseline:.2f}s 的 1.5 倍"
    
    # 6. 更新基线
    save_baseline('query_xyz', {'p50': p50, 'p95': p95})
```

💡 **为什么**：
- 单次测试不准确（冷启动、JIT 编译等影响）
- 没有基线对比，性能回归无法发现
- 多轮 + P50/P95 是性能测试的正确做法

---

## 3. 测试代码示例

### 3.1 完整的 SCD Type 2 测试

```python
import pytest
from datetime import date

@pytest.fixture
def user_history_table():
    """SCD Type 2 历史表 fixture"""
    return "dim_user_test"

def test_scd2_first_insert():
    """首次插入：当前版本"""
    user_id = 1
    create_user(user_id=user_id, level='A', city='Beijing')
    
    history = get_user_history(user_id)
    assert len(history) == 1
    assert history[0]['level'] == 'A'
    assert history[0]['valid_from'] == date.today()
    assert history[0]['valid_to'] == date(9999, 12, 31)
    assert history[0]['is_current'] is True

def test_scd2_attribute_change_creates_new_version():
    """属性变化：创建新版本，旧版本失效"""
    user_id = 2
    create_user(user_id=user_id, level='A', city='Beijing')
    
    # 修改等级
    update_user_level(user_id, 'B')
    
    history = get_user_history(user_id)
    assert len(history) == 2
    
    # 旧版本：失效
    old = [h for h in history if not h['is_current']][0]
    assert old['level'] == 'A'
    assert old['valid_to'] == date.today()  # 失效日期 = 变更日
    
    # 新版本：当前
    new = [h for h in history if h['is_current']][0]
    assert new['level'] == 'B'
    assert new['valid_from'] == date.today()

def test_scd2_no_change_no_new_version():
    """属性未变化：不创建新版本"""
    user_id = 3
    create_user(user_id=user_id, level='A')
    
    # 相同数据再跑一次
    sync_user_dimension([{'user_id': user_id, 'level': 'A'}])
    
    history = get_user_history(user_id)
    assert len(history) == 1  # 仍然只有 1 个版本
```

### 3.2 跨表对账测试

```python
def test_dws_aggregation_matches_dwd():
    """DWS 聚合应等于 DWD 原始数据"""
    # 1. 准备测试数据
    test_date = '2024-01-15'
    seed_dwd_orders(test_date, orders=[
        {'user_id': 1, 'order_id': 101, 'amount': 100.0},
        {'user_id': 1, 'order_id': 102, 'amount': 200.0},
        {'user_id': 2, 'order_id': 103, 'amount': 150.0},
    ])
    
    # 2. 运行 DWS ETL
    run_etl('dws_trade_user_1d', bizdate=test_date)
    
    # 3. 查询 DWS 结果
    dws_user1_amount = query_dws(
        f"SELECT pay_amount_1d FROM dws_trade_user_1d "
        f"WHERE user_id = 1 AND pt = '{test_date.replace('-', '')}'"
    )
    
    # 4. 断言：DWS 聚合 = DWD 原始数据
    expected_user1_amount = 100.0 + 200.0  # = 300.0
    diff = abs(dws_user1_amount - expected_user1_amount)
    assert diff < 0.01, f"用户 1 DWS 金额 {dws_user1_amount} 与 DWD 不一致，差异 {diff}"
```

### 3.3 性能回归测试

```python
import time
import statistics
import json

class PerformanceTracker:
    """性能基线跟踪器"""
    
    def __init__(self, baseline_file='performance_baselines.json'):
        self.baseline_file = baseline_file
        self.baselines = self._load()
    
    def _load(self):
        try:
            with open(self.baseline_file) as f:
                return json.load(f)
        except FileNotFoundError:
            return {}
    
    def test_query_performance(self, query_name, sql, max_regression=1.5):
        """测试查询性能，对比基线"""
        # 1. 预热
        execute_sql(sql)
        
        # 2. 多轮执行
        durations = []
        for _ in range(5):
            start = time.time()
            execute_sql(sql)
            durations.append(time.time() - start)
        
        # 3. 计算 P50/P95
        p50 = statistics.median(durations)
        p95 = sorted(durations)[int(len(durations) * 0.95)]
        
        # 4. 对比基线
        if query_name in self.baselines:
            baseline_p95 = self.baselines[query_name]['p95']
            regression_factor = p95 / baseline_p95
            
            assert regression_factor < max_regression, \
                f"性能回归: {query_name} P95 = {p95:.2f}s, " \
                f"基线 = {baseline_p95:.2f}s, " \
                f"回归倍数 = {regression_factor:.2f}x"
        
        # 5. 更新基线（仅当性能更好时）
        if query_name not in self.baselines or p95 < self.baselines[query_name].get('p95', float('inf')):
            self.baselines[query_name] = {'p50': p50, 'p95': p95}
            with open(self.baseline_file, 'w') as f:
                json.dump(self.baselines, f, indent=2)

# 使用示例
def test_sales_dashboard_performance():
    tracker = PerformanceTracker()
    sql = "SELECT user_id, SUM(amount) FROM dws_trade_user_1d WHERE pt = '20240115' GROUP BY user_id"
    tracker.test_query_performance('sales_dashboard_query', sql, max_regression=1.5)
```

## 4. 经验教训

### 踩坑 #1：测试跑得太慢，团队不爱用

**场景**：完整测试套件需要 30 分钟才能跑完，开发者不愿意本地跑，CI 也很慢。
**原因**：测试金字塔倒置，太多集成测试和 UI 测试。
**解决**：拆分测试为"快测试"（单元测试，1 分钟）和"慢测试"（集成/E2E，30 分钟）。本地跑快测试，CI 跑全量。
**预防**：测试速度纳入规范，单元测试必须 < 1 秒/个。

### 踩坑 #2：测试数据污染生产

**场景**：测试误用了生产 schema，导致部分测试数据写到了生产表。
**原因**：连接串配置错误，没明确指定测试环境。
**解决**：所有测试连接串必须显式带 `_test` 后缀，CI 强制校验。
**预防**：使用单独的测试 schema，独立的连接用户。

### 踩坑 #3：性能基线一直更新导致漏掉回归

**场景**：每次性能测试都比上一次快，因为测试用的数据量在减少，基线被不断"刷新"。
**原因**：测试数据不是固定规模。
**解决**：测试数据固定（如 1 年历史数据），基线才不会漂移。
**预防**：测试数据集大小固定，定期用全量数据重测。

### 踩坑 #4：覆盖率虚高

**场景**：报告显示 90% 覆盖率，但实际只测了 5% 的业务场景。
**原因**：覆盖率工具统计的是"行执行"，不是"业务场景"。
**解决**：定义关键业务场景清单（10-20 个），每个场景必须有测试。
**预防**：覆盖率分两层：行覆盖 + 业务场景覆盖。

### 踩坑 #5：测试通过但生产出问题

**场景**：所有测试都通过，但生产还是出错。
**原因**：测试环境数据规模小、配置不同，没覆盖真实生产场景。
**解决**：增加"预生产"测试环节，用生产规模数据跑测试。
**预防**：建立"测试环境 = 生产环境"配置规范。

## 5. 协作建议

### 5.1 与开发协作

| 协作点 | 建议 |
|--------|------|
| TDD | 关键模块先写测试再写实现 |
| Code Review | 包含测试代码 review |
| 测试覆盖 | 新代码覆盖率不能低于团队基线 |
| 失败处理 | 测试失败应阻塞合并 |

### 5.2 CI/CD 集成

```yaml
# .github/workflows/test.yml
name: 数据测试

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: 单元测试（快，< 5 分钟）
        run: |
          pytest tests/unit/ -v --maxfail=5
          
  integration-tests:
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v2
      - name: 集成测试（中等，< 20 分钟）
        run: |
          pytest tests/integration/ -v
          
  e2e-tests:
    runs-on: ubuntu-latest
    needs: integration-tests
    # 仅在合并到主分支时跑
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v2
      - name: 端到端测试（慢，< 60 分钟）
        run: |
          pytest tests/e2e/ -v
```

### 5.3 测试报告展示

```python
# pytest 配置（pytest.ini 或 conftest.py）
[pytest]
addopts = 
    --html=reports/report.html
    --cov=src
    --cov-report=html:reports/coverage
    --cov-report=term
    --junit-xml=reports/junit.xml
    
# 关键测试用 marker 标记
# @pytest.mark.smoke  # 冒烟测试
# @pytest.mark.regression  # 回归测试
# @pytest.mark.performance  # 性能测试
```

---

**附录**：
- 详细规范：[test-standards.md](test-standards.md)
- 单元测试示例：[example-unit-test.md](../examples/example-unit-test.md)
- 集成测试示例：[example-integration-test.md](../examples/example-integration-test.md)
- 性能测试示例：[example-performance-test.md](../examples/example-performance-test.md)
