# mooncloc 项目申报书

> 本文件与报名表单「项目申报书」字段提交的内容一致（mooncloc_proposal.md）。

**基本信息**
- 项目名称：mooncloc：MoonBit 生态的代码统计与圈复杂度分析工具
- 参赛者：Krinph
- 联系方式：1487086852@qq.com
- GitHub 仓库链接：https://github.com/Krinph/mooncloc
- 项目方向：开发者工具 / 代码统计与工程质量分析
- 是否为移植项目：否（原创项目）

**项目简介**

mooncloc 是一个用 MoonBit 实现的 cloc 风格代码统计工具，同时提供库 API 与命令行工具。它递归扫描目录树，按语言统计代码行、注释行、空白行与混合行，计算每个文件的圈复杂度，并输出注释率、复杂度密度、最复杂文件等健康指标，支持表格 / JSON / CSV / Markdown 四种报告格式。项目面向需要在 MoonBit 或混合语言工程中度量代码规模、做代码质量体检、以及搭建 CI 质量门禁的开发者，目前已完成 45 种语言支持并开源，包含完整的测试与三平台持续集成。

**核心功能范围**

- 提供行级统计引擎，按语言剥离注释与字符串字面量（行注释、块注释、嵌套块注释、多行字符串、raw 字符串、shebang），正确区分代码/注释/空白/混合行；
- 提供 45 种语言的识别定义表，以 MoonBit 为第一优先，覆盖 C/C++/Rust/Go/Python/JavaScript/TypeScript/Java 等主流语言；
- 提供圈复杂度分析，统计 if/elif/match/for/while/loop/guard/catch/case/when/switch 及 &&、||、? 等分支点，并排除注释与字符串内容；
- 提供 gitignore 风格的排除规则（*、?、**、目录模式、锚定模式）与内置噪音目录排除，支持语言过滤与隐藏文件选项；
- 提供健康指标与报告：注释率、每百行复杂度、最复杂文件排名，以及对齐表格、JSON（含 health 段）、CSV、Markdown 四种输出；
- 提供 CLI 与库双层 API：`moon run cmd/main` 直接运行，`moon add Krinph/mooncloc` 可作为库嵌入其他项目；
- 提供不少于 41 个单元与端到端测试并持续保持回归通过，GitHub Actions 三平台（Linux/macOS/Windows）CI 覆盖 check/test/fmt 检查；
- 提供 README 与 samples 示例，覆盖目录统计、语言过滤、排除规则与四种报告格式的演示。

**原创与参考说明**

本项目为原创项目，非移植项目。统计口径与功能设计参考了通用工具 cloc（仅参考其统计口径与功能划分，未使用其代码，无移植关系）；语言识别规则表依据各语言公开语法事实整理；不依赖、不复制 MoonBit 生态中任何既有项目。本项目许可证为 Apache-2.0。

与参考工具 cloc 相比，本项目做以下简化和重新设计：

- 使用 MoonBit 原生包结构、类型系统与测试方式组织代码，而非 Perl 脚本结构；
- 面向 MoonBit 生态优先设计：可作为库嵌入 MoonBit 工程，对 MoonBit 语法（#| 多行字符串、/// 文档注释、guard 等）有专属识别；
- 以表格 / JSON / CSV / Markdown 为主要交付接口，JSON 输出附带 health 健康指标段，便于接入 CI 与自动化分析场景；
- 统计口径与 cloc 保持一致（混合行计入代码行、多行字符串计入代码行），差异已文档化说明。
