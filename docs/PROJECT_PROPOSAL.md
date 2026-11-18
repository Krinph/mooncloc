# mooncloc 项目申报书

> 本文件与报名表单「项目申报书」字段提交的内容一致（mooncloc_proposal.md）。
> 针对初审回信的补充说明详见 `docs/COMPARISON.md`（含同工程输出对比）。

**基本信息**
- 项目名称：mooncloc：MoonBit 生态的代码质量回归门禁工具
- 参赛者：Krinph
- 联系方式：1487086852@qq.com
- GitHub 仓库链接：https://github.com/Krinph/mooncloc
- 项目方向：开发者工具 / 工程质量与 CI 门禁
- 是否为移植项目：否（原创项目）

**项目简介**

mooncloc 是纯 MoonBit 实现的工程质量门禁工具。它并不与既有的 TokeiMBT 竞争代码统计：统计层只作为地基，本项目的独立贡献在其之上的**时间维度**——把一次性的「有多少代码」升级为可持续的「这次改动是否让代码变差，并让 CI 自动拦截」。核心新增能力为：保存自描述基线快照、对同一工程做逐文件差异对比（新增/删除/变更 + 代码/注释/空白/复杂度增量）、按可配置策略（代码增长、复杂度增长、注释率下限、单文件复杂度上限）产出 pass/fail 与 CI 退出码。它可直接读取 TokeiMBT/tokei 的 JSON 报告作为基线，从而复用现有计数器的输出而不重复实现其职责。项目提供库 API 与 CLI，含 57 项测试、三平台 CI，并附带可复现的同工程对比材料。

**核心功能范围**

- 提供行级统计引擎与 45 种语言定义（含 MoonBit `#|` 多行字符串、`///` 文档注释、`guard` 等专属语法），作为门禁的指标来源；
- 提供圈复杂度分析，统计 if/elif/match/for/while/loop/guard/catch/case/when/switch 及 &&、||、? 等分支点，排除注释与字符串；
- **【新增用途】提供基线快照**：`--snapshot FILE` 输出带版本与来源标记的逐文件指标 JSON，可入库、可评审、可跨机器比对；
- **【新增用途】提供回归对比**：`--baseline FILE` 对同一工程计算逐文件 added/removed/changed/unchanged 与各项增量；采用唯一后缀路径匹配，兼容 TokeiMBT 的相对路径与本地扫描的绝对路径，避免同名误配；
- **【新增用途】提供质量门禁**：`--check` 配合 `--max-code-growth`、`--max-complexity-growth`、`--min-comment-ratio`、`--max-file-complexity` 四条策略，输出人类可读与 JSON 两种判定结果，违规时进程退出码 1，可直接接入 CI 阻断合并；
- **【复用方案】提供 TokeiMBT/tokei JSON 基线导入**：`--baseline tokei-report.json` 直接复用 TokeiMBT 原生输出作为基线；对基线不含的复杂度数据明确标记并跳过相应规则，不静默误判；
- 提供 gitignore 风格排除规则、语言过滤、隐藏文件选项与四种报告格式（table/JSON/CSV/Markdown）；
- 提供 CLI 与库双层 API：`moon run cmd/main` 直接运行，`moon add Krinph/mooncloc` 可嵌入其他 MoonBit 工程；
- 提供 57 项单元与端到端测试、GitHub Actions 三平台 CI（check/test/fmt），以及 README、samples 与 `docs/COMPARISON.md` 可复现对比材料。

**与现有工具的关系（复用 / 扩展 / 差异）**

本项目尊重既有生态分工，明确分层，不做重复建设：

- **复用**：TokeiMBT 已完整覆盖 333 种语言的行统计。本项目按其公开 JSON 格式读取其报告作为基线（接口级复用，非代码复用），使用方无需改变已有计数步骤。
- **扩展**：在计数结果之上新增持久化基线、逐文件差异、增量阈值与 CI 退出码——这些是 TokeiMBT 作为无状态计数器在架构上不提供的能力。
- **差异**：TokeiMBT 回答「现在有多少代码」（描述性统计），mooncloc 回答「这次改动是否让代码变差、是否该拦截」（工程决策）。两者可并存，后者以前者输出为输入。

同工程输出对比（保存基线 → 加入高分支函数 → 门禁判定 FAIL，退出码 1）见 `docs/COMPARISON.md`，所有输出为本地实测。

**原创与参考说明**

本项目为原创项目，非移植项目。未使用、未复制 Tokei/TokeiMBT 的源代码；仅按其公开 JSON 报告格式做兼容读取，属于公开接口复用。统计口径参考通用工具 cloc（仅参考口径与功能划分，未使用其代码）。语言识别规则依据各语言公开语法事实整理。许可证 Apache-2.0。

与 cloc 相比的重新设计：MoonBit 原生包结构与类型系统；面向 MoonBit 生态优先；以 table/JSON/CSV/Markdown 为交付接口；新增基线对比与 CI 门禁层；统计口径差异已文档化（混合行计入代码行、多行字符串计入代码行）。
