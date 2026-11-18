# mooncloc 与现有统计工具的差异与净贡献

> 面向 MoonBit 开源大赛十一月黑客松初审回信的补充说明。
> 回信要求：「补充与现有工具的复用、扩展或差异方案，并以同一工程的输出对比说明新增用途。」
> 本文档逐条回应，所有输出均为本地实际运行结果（moonc v0.10.20，native 目标）。

---

## 1. 结论先行

| 问题 | 回应 |
|---|---|
| 是否与 TokeiMBT 重复？ | **统计层有意对齐、并直接复用其输出**；本项目的独立贡献在统计**之上**的时间维度与决策层。 |
| 净贡献是什么？ | 把一次性的「有多少代码」升级为可持续的「这次改动是否让代码变差，并让 CI 自动拦截」。 |
| 新增用途是什么？ | **基线快照 + 回归对比 + 质量门禁**，TokeiMBT 作为无状态计数器在架构上不提供该用途。 |
| 是原创吗？ | 是。未移植、未复制 Tokei/TokeiMBT 代码；仅按其公开 JSON 格式做兼容读取（复用接口，非复用实现）。 |

---

## 2. 与 TokeiMBT 的关系：复用 + 扩展 + 差异

TokeiMBT（`aicongli-829/tokei@0.1.1`）是一个优秀的 Tokei 移植：333 种语言、行/注释/空白分类、按语言聚合、table/JSON/CSV/YAML 输出。它把「计数」做得很完整。**本项目不与之竞争计数能力**，而是明确分层：

```
                       ┌──────────────────────────────────────┐
   新增用途（mooncloc）  │ 基线快照 → 差异对比 → 质量门禁 → CI 退出码 │
                       └───────────────────┬──────────────────┘
                                           │ 读取其 JSON 报告作为基线
                       ┌───────────────────▼──────────────────┐
   统计层（可复用）      │ TokeiMBT / tokei / mooncloc 任意一种计数器 │
                       └──────────────────────────────────────┘
```

### 2.1 复用（Reuse）：可直接吃 TokeiMBT 的报告

`mooncloc --baseline tokei-report.json --check ...` 会读取 **TokeiMBT 原生 JSON 格式**（`{"Rust":{"reports":[{"name":...,"stats":{...}}]}}`），无需先迁移计数步骤。已在 `baseline_wbtest.mbt` 中用真实格式样例覆盖测试。

- 路径兼容：TokeiMBT 常用相对路径、mooncloc 扫描常用绝对路径；采用「唯一后缀匹配」对齐，且避免同名文件误配（有对应测试）。
- 语义诚实：TokeiMBT 不含圈复杂度，导入后复杂度记 0，**门禁自动跳过复杂度规则并显式提示**，绝不静默误判。

### 2.2 扩展（Extend）：在计数之上新增决策能力

| 能力 | TokeiMBT | mooncloc（本次新增） |
|---|---|---|
| 一次性统计 | ✅ | ✅（对齐口径） |
| 圈复杂度 | ❌ | ✅ |
| 保存可比对基线 | 仅 `-i` 合并，无快照语义 | ✅ `--snapshot` 自描述快照（含版本、来源、逐文件指标） |
| 两版工程逐文件差异 | ❌ | ✅ added / removed / changed / unchanged + 逐项 Δ |
| 增量门禁（阈值 + 退出码） | ❌ | ✅ 4 条策略规则，`--check` 违规 `exit 1` |
| 跨工具基线（复用他工具输出） | ❌ | ✅ 读取 TokeiMBT / tokei JSON |

### 2.3 差异（Differentiate）：定位不同

- **TokeiMBT 回答**：“这个工程现在有多少行代码？”
- **mooncloc 回答**：“相对已批准基线，这次提交多写了多少、复杂度涨了多少、注释率掉没掉——是否该合并？”

前者是**描述性统计**，后者是**工程决策**。两者可并存，且后者以前者的输出为输入。

---

## 3. 同一工程的输出对比

场景：一个小型 MoonBit 工程 `src/app.mbt`（2 个函数，12 行代码，圈复杂度 2）。先保存基线，再向同一文件加入一个高分支函数 `risky`（含 `&&`、`||`、嵌套 `if`），然后对**同一路径**重新运行。

### 3.1 仅计数：TokeiMBT / mooncloc 默认模式（两者视觉一致）

```
Language  Files  Blank  Comment  Code  Complexity
--------  -----  -----  -------  ----  ----------
MoonBit       1      1        3    12           2
--------  -----  -----  -------  ----  ----------
Total         1      1        3    12           2
```

这一步说明：**统计层确实同质**，初审意见成立——因此本项目没有把「改进统计」作为申报重点。

### 3.2 新增用途：基线快照 + 回归门禁（改动后，同一工程）

```
$ mooncloc --baseline baseline.json --check --max-code-growth 3 --max-complexity-growth 1 src/

File                                         Language   Status  Code  Comment  Blank  Cx
-------------------------------------------  --------  -------  ----  -------  -----  --
C:/Users/14870/Desktop/挣米/_demo/src/app.mbt   MoonBit  changed    +7       +1     +1  +4

files: +0 added, -0 removed, ~1 changed, 0 unchanged
totals: code +7 (12 -> 19), comment +1, blank +1, complexity +4

quality gate: FAIL (2 violation(s))
  [max_code_growth] code grew by +7 lines (limit +3)
  [max_complexity_growth] complexity grew by +4 (limit +1)
```

进程退出码为 **1**（原生二进制实测），可直接用于 GitHub Actions / CI 阻断合并。

### 3.3 机器可读输出（CI 仪表盘）

```
$ mooncloc --baseline baseline.json --check --max-code-growth 3 -f json src/
{
  "source": "mooncloc",
  "code_delta": 7,
  "complexity_delta": 4,
  "changed": 1,
  "gate_passed": false,
  "complexity_rules_skipped": false,
  "changes": [ { "path": "...", "status": "changed", "code_delta": 7,
                 "comment_delta": 1, "complexity_delta": 4 } ],
  "violations": [ { "rule": "max_code_growth",
                    "detail": "code grew by +7 lines (limit +3)" } ]
}
```

### 3.4 复用 TokeiMBT 报告作为基线（同一工程）

```
$ mooncloc --baseline tokei-report.json --check --max-code-growth 3 src/
File                                         Language   Status  Code  Comment  Blank  Cx
-------------------------------------------  --------  -------  ----  -------  -----  --
C:/Users/14870/Desktop/挣米/_demo/src/app.mbt   MoonBit  changed    +7       +1     +1  +4

totals: code +7 (12 -> 19), comment +1, blank +1, complexity +4
quality gate: FAIL (1 violation(s))
  [max_code_growth] code grew by +7 lines (limit +3)
  note: baseline source has no complexity data; complexity rules skipped
```

注意末行提示：来自 TokeiMBT 的基线不含复杂度，因此**只执行其能支持的代码量规则**，体现了复用的边界与诚实性。

---

## 4. 可复现步骤

```text
# 1. 保存基线
moon run cmd/main -- --snapshot baseline.json src/

# 2. 修改 src/ 中的代码

# 3. 门禁检查（违规时退出码 1）
moon run cmd/main -- --baseline baseline.json --check \
  --max-code-growth 3 --max-complexity-growth 1 src/

# 3b. 或复用 TokeiMBT 报告做基线
moon run cmd/main -- --baseline tokei-report.json --check --max-code-growth 3 src/
```

测试：`moon check`、`moon test`（57 项通过）、`moon fmt --check` 均通过。
新增测试文件 `baseline_wbtest.mbt` 覆盖快照往返、Tokei 格式导入、差异计算、四条门禁规则、跨工具路径匹配与歧义保护。

---

## 5. 对初审意见的逐条回应

> 「现有 TokeiMBT 已覆盖主要统计职责」

成立。本项目保留统计层仅为兼容与自举，**申报的核心工作已转移到其之上的时间维度与 CI 决策层**，并以第 3 节的同工程输出对比证明新增用途。

> 「局部语法适配、分支词计数、派生指标和报告格式，尚未建立足以支撑独立项目的实质差异与净贡献」

该批评针对的是「把统计做得更细」的方向。本项目已放弃该论证路径，改为提供 TokeiMBT 架构上不提供的能力：**持久化基线、逐文件回归对比、可配置的自动门禁、跨工具基线复用**。这是一条独立的用途轴线，而非同一用途的增量改良。

> 「请补充与现有工具的复用、扩展或差异方案」

见第 2 节：复用其 JSON 报告为基线（接口级复用），扩展其统计结果为可判定信号，差异在于从描述性统计升级为工程决策。
