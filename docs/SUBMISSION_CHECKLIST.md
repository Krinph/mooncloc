# 报名提交清单与表单填写指引

> 2026 MoonBit 国产基础软件开源大赛 · 11月黑客松（十一月赛季）
> 报名表单：https://bxup9uklfcb.feishu.cn/share/base/form/shrcnWUMlgpbwHaXgzV7HmNhNhg
> 表单仅能提交 3 次（可修改），提交后会自动跳转赛事群二维码，**务必入群并把群昵称改为 GitHub ID：Krinph**。

---

## 〇、初审未通过后的重新申报要点（2026-11-18 更新）

回信核心意见：统计用途与 TokeiMBT 重合，局部语法/分支词/派生指标/报告格式不构成实质差异；
要求补充「与现有工具的复用/扩展/差异方案」并以「同一工程的输出对比说明新增用途」。

已完成的工作：

1. **重新定位**：从「又一个 cloc」改为「代码质量回归门禁工具」——统计层是地基，净贡献在其上的时间维度与 CI 决策层。
2. **新增用途（已实现）**：`--snapshot` 基线快照 → `--baseline ... --check` 逐文件回归对比 → 四条质量门禁策略 + CI 退出码。
3. **复用方案（已实现）**：`--baseline tokei-report.json` 直接读取 TokeiMBT/tokei JSON 报告为基线，接口级复用，不重复其计数职责；复杂度数据缺失时诚实跳过相应规则。
4. **对比证据**：`docs/COMPARISON.md` 含同工程 before/after 实测输出与逐条回应。
5. **提交动作**：
   - 将本次改动提交并推送到 GitHub（新增 baseline.mbt、baseline_wbtest.mbt、docs/COMPARISON.md，更新申报书/README/CI）；
   - 在表单「项目申报书」字段粘贴 `docs/PROJECT_PROPOSAL.md` 的新版内容（突出门禁/复用/差异）；
   - 在「备注」中附加 `docs/COMPARISON.md` 的 GitHub 链接，方便评委直接查看对比证据；
   - 于 2026-11-30 前重新提交表单等待复审。

---

## 一、提交前必检（对照章程验收 8 项）

| # | 要求 | 状态 | 说明 |
|---|---|---|---|
| 1 | 以 MoonBit 为主要实现语言 | ✅ | 约 3000 行 MoonBit 代码，9 个模块 + CLI |
| 2 | GitHub 仓库公开、提交记录清晰 | ✅ | https://github.com/Krinph/mooncloc，19 个语义化提交 |
| 3 | 源码结构清晰、完成核心功能 | ✅ | 统计层 + 新增质量门禁层（baseline.mbt），功能全部实现 |
| 4 | README 可复现 | ✅ | 含安装/使用/示例/统计口径/质量门禁，`moon run cmd/main -- .` 可复现 |
| 5 | CI 覆盖检查/构建/测试 | ✅ | GitHub Actions 三平台全绿（check --deny-warn / test / fmt / info / dogfood） |
| 6 | 至少一个可运行示例 | ✅ | `samples/`（MoonBit/Python/Rust）+ README 示例 |
| 7 | 完整测试覆盖核心路径 | ✅ | 57 个测试全部通过（新增门禁 15 项） |
| 8 | 发布到 mooncakes.io | ⏳ **验收前完成** | 已登录 mooncakes（Krinph），需创建 API token → `moon login <token>` → `moon publish` |

> 另：参赛者须加入赛事交流群并将群昵改为 GitHub ID（Krinph），否则影响奖金发放。

## 二、报名表单逐字段填写指引

| # | 字段 | 推荐填写 | 备注 |
|---|---|---|---|
| 1 | 是否参加过 MoonBit 黑客松 | **由您填写** | 按实际情况选是/否 |
| 2 | 参赛方向 | **新项目申报-参与季度评选**（推荐） | 参与季度评选可叠加季度/半年度/年度奖金 |
| 3 | 姓名 | **由您填写** | |
| 4 | 联系方式（邮箱） | **由您填写** | 不要用 Gmail 等国外邮箱，建议 QQ 邮箱 |
| 5 | 联系方式（电话） | **由您填写** | 尽量填能加微信的电话 |
| 6 | 身份证号码 | **由您填写** | 发奖金需要，仔细核对 |
| 7 | 项目名称 | `mooncloc` | |
| 8 | 项目的GitHub仓库链接 | `https://github.com/Krinph/mooncloc` | |
| 9 | 银行卡账号 | **由您填写** | 不要空格；团队格式见表单说明 |
| 10 | 银行卡所属分行 | **由您填写** | 例如：中国银行深圳科创支行 |
| 11 | 推荐人 | 无推荐人可留空；如有人推荐填其 GitHub ID | 推荐人须已是报名成功选手 |
| 12 | 《参赛诚信承诺书》 | 阅读后勾选「我已阅读并同意」 | 承诺真实参赛、信息属实 |
| 13 | 备注 | 建议填写：项目申报书详见 https://github.com/Krinph/mooncloc/blob/main/docs/PROJECT_PROPOSAL.md ；与 TokeiMBT 的差异及同工程输出对比见 https://github.com/Krinph/mooncloc/blob/main/docs/COMPARISON.md | 强调新增用途与复用方案 |
| 14 | 渠道 | 按实际情况选 | 填答可参与抽奖 |

## 三、提交后的流程

1. 报名提交 → 自动跳转赛事群二维码 → **扫码入群，群昵称改为 Krinph**；
2. 赛方审核申报书并邮件通知（约 1 个工作日）；未通过可修改问卷重新申报；
3. 通过后发放 150 元启动支持；
4. 赛季内持续公开提交（保留 commits/Issues/PR 记录）；
5. 验收阶段（官方通知）→ 完成 mooncakes.io 发布（第 8 项）→ 通过后发放 350 元完成支持；
6. 季度优秀项目评选 → 一等奖 12,000 元 / 二等奖 6,000 元 / 三等奖 3,000 元。

## 四、备用链接

- 赛事章程（飞书）：https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd
- 赛事官网：https://moonbitlang.github.io/Hackathon2026/
- 申报书：https://github.com/Krinph/mooncloc/blob/main/docs/PROJECT_PROPOSAL.md
- mooncakes 发布：https://mooncakes.io/settings （创建 API token）
