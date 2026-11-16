# 测试报告

更新日期：2026-11-16。当前阶段：Phase 4 测试与诊断；逐项状态见 phase4-evidence.md。

产品结论：**Phase 1–3 代码及自包含载荷已实现，硬件与完整产品验收未完成，不能发布 v1.0。**

| 范围 | 状态 | 说明 |
|---|---|---|
| Swift 编译 | PASS | 已有完整核心，本轮 make build 通过 |
| 自动化测试 | PASS | 44 项核心断言、88 项集成检查、64 项快捷指令及 37 项诊断/失败路径检查 |
| T01–T31 | 分层记录 | 见 phase4-evidence.md，不能将模拟替代真实层 |
| 真实鼠标/触摸板 | 本机用户观察PASS | 小米无线鼠标3/2.4G + 内置触摸板；见 compatibility.md |
| Apple Silicon / Intel | arm64本机部分PASS；Intel未验证 | 本轮E1单机证据，不推广系统/架构兼容性 |
| 快捷指令/iCloud | 部分自动化通过 | 已生成自包含载荷；应用内创建、原生导入及跨 Mac 同步未验证 |
| 性能/权限/生命周期 | 部分真实PASS | 300秒健康空闲采样及信号/异常退出通过；撤销授权/登录休眠等未完成 |

## 执行记录模板

- 日期、执行人、Git 提交、载荷哈希：
- macOS / Swift / 架构 / 设备与连接方式：
- 用例编号、前置条件、步骤：
- 预期与实际结果：
- 结论：PASS / FAIL / BLOCKED / 未验证
- 证据、缺陷、复测结果：

## 历史：初始化验证

初始化当时尚无实现及测试代码；初始化检查只验证目录、需求原文一致性、文档链接与 Makefile 入口，不代表产品验收通过。具体检查结果见本次交付说明。

## Phase 1 实施记录（2026-11-16）

- 环境：Apple Silicon arm64；Swift 6.4.2，编译器目标 arm64-apple-macosx27.2.0。
- `make build`：PASS，优化编译生成 build/mousescrolltoggle。
- `make test`：PASS，35 项断言；覆盖 T17/T18 的最小事件/纯函数范围与 T19 的恢复预算部分。
- `zsh -n Scripts/build.sh Tests/run-tests.sh`：PASS。
- `--help`、`--version`：PASS。
- `--check-permission`：输出未授权；实际启动返回 2，并输出系统设置授权指引。权限失败路径符合预期。
- 实际服务未进入运行状态；T01–T06、真实 Tap 创建、禁用恢复、信号清理、权限撤销、性能和 Intel 均未验证。
- Phase 1 实现已交付，但“鼠标反转、触摸板不变”的硬件验收未完成；不宣称整个 Phase 1 验收或 v1.0 发布完成。

以上新记录更新初始化快照中编译与自动化测试的状态；其他未验证项目保持原状。

## Phase 2 实施记录（2026-11-16）

- make build：PASS；make test：PASS（35 项）；make integration-test：PASS（24 项隔离模拟检查）。
- Zsh 语法检查及 git diff --check：PASS。
- 真实系统测试：临时 HOME、独立 local.mousescrolltoggle.test.<pid>，使用实际 /bin/launchctl 和本机核心；install 成功，bootstrap 后核心报缺少辅助功能权限；start=1、status=ERROR/1；stop 与 uninstall 成功，临时目录已清理。没有修改真实用户安装。
- 未验证：健康 Tap 的真实 SIGUSR1 响应、实际单实例争用、信号释放 Tap、系统禁用恢复、权限撤销、硬件滚动、休眠、登录退出/重新登录、Intel 和性能。
- 人工步骤：授权稳定二进制，start/status 应 RUNNING；再次 start PID 应不变；直接运行第二实例应返回 5；发送 TERM 后 status 应 ERROR；再次 start 可恢复；撤销权限后查询应 ERROR；stop 后不应重启。开启后退出登录再登录，应 STOPPED；休眠唤醒、设备重连后按 T01–T06/T19/T22–T24 检查鼠标与触摸板。记录实际结果，不将此步骤表视为通过。

## Phase 2 review 回归记录

- `make build`、`make test`（35 项）、`make integration-test`（87 项）、全部脚本 Zsh 语法检查和 `git diff --check` 通过。扩展集成测试覆盖前台锁占用、陈旧 PID 不被信号终止、更新启动失败后 bootout 失败/停止超时、恢复文件失败、旧服务恢复失败、完整备份保留、执行恢复脚本及成功后清理。
- 模拟层：临时 HOME、独立服务名、mock launchctl/core；失败注入仅在 MST_TEST_MODE=1 下启用。不能据此宣称真实 Tap 或硬件通过。
- 真实核心层：同一隔离 HOME 下持有实际内核 core.lock，运行本机编译的真实核心返回 5；证明 Swift/Zsh 锁互通。该测试未创建 Tap，不属于真实健康前台实例验证。
- 仍未验证：获授权的真实前台核心持续运行与 Tap 清理、真实 launchctl 故障恢复、Tap 禁用恢复、权限撤销、鼠标/触摸板、休眠、退出登录、Intel 及性能。权限阻塞保持原记录。

- 本轮真实 launchctl 复测：临时 HOME、独立服务名、实际 launchctl 与本机编译核心。缺少辅助功能权限，start=1、status=ERROR/1；stop、uninstall 成功，临时安装和测试服务已清理。仍不表示真实 Tap 成功运行。

## Phase 3 实施记录（2026-11-16）

- 版本来源 VERSION=0.3.0（开发阶段版本）。核心 --version 返回协议标识 core-protocol=1，避免仅产品版本变化替换核心。原始 requirements.md 未修改。
- `make build`：PASS；`make test`：PASS（35 项）；`make integration-test`：PASS（87 项）。安装器提取为内部函数后，原事务与核心锁回归保持通过。
- `make shortcut-test`：PASS（64 项）；覆盖确定性生成、正式源码一致性、Shell 语法、无开发路径/下载依赖、离仓库运行、特殊字符路径、首次点击只启动一次、开启/关闭/开启、无意义编译避免、版本/脚本/核心更新、编译及未就绪失败不输出成功、更新失败不切换、未完成事务阻止叠加、旧载荷拒绝、保留 bundle 摘要与临时载荷清理后的独立恢复，以及四次并发点击串行结束于停止。
- `make check-shortcut`、所有 Scripts/Tests/载荷 Zsh 语法检查及 `git diff --check`：PASS。产物纳入 Git，无时间戳、凭据或本机二进制。
- 模拟层：临时 HOME 与 TMPDIR（含空格、单引号、&、XML 特殊字符），独立服务名，显式 mock launchctl/core/build。结果只证明编排/事务行为，不证明真实 Tap、硬件、快捷指令 UI 或 iCloud。
- 真实系统层：完整载荷在临时 HOME、独立服务名下运行，使用实际 launchctl 和解包的 Swift 源码经 xcrun 本机编译；测试模式仅用于选定服务名/launchctl 路径，未替换编译器。安装成功，启动因辅助功能缺失失败，点击退出 1、stdout 为空，没有输出“已开启”；status=ERROR/1；stop、uninstall 成功，服务及临时安装已清理。另一次预编译核心适配器运行结果相同，不能算作独立硬件证据。
- 快捷指令交付核实：本机 `shortcuts --help` 列出 run/list/view/sign，没有从 Shell 文本创建快捷指令的公开子命令；`shortcuts sign --help` 确认输入须为已有快捷指令。参考 Apple 官方命令行、脚本许可与 iCloud 文档（链接见 Shortcuts/README.md）。不构造私有格式，本轮交付完整文字创建步骤，未生成原生 .shortcut，不声称已创建/导入/签名/同步。
- 未验证：快捷指令应用内真实执行及宿主授权条目、第二台 Mac/iCloud、Intel、授权后的健康 Tap、设备兼容性、Tap 恢复、休眠、登录退出和性能。人工步骤见 Shortcuts/README.md 和 acceptance-tests.md；完成创建后在本机三次点击验证开/关/开，再在第二台 Mac 同步后独立安装授权并记录环境与真实结果。不宣称 v1.0 完成。

- 关闭意图的核心更新不会重启新服务；自动化检查 bootstrap 次数不增加。源文件和 bundle 摘要另与载荷解包安装后的记录逐字节对应，确认未嵌入另一套实现。


## Phase 4 实施记录（2026-11-16）

环境与源码身份见 Tests/results/environment.txt。本轮真实结果与历史记录严格分开，不借用旧提交的运行结果。完整 T01–T31 证据表见 phase4-evidence.md。

- 已实现正式 doctor 与载荷 --doctor：未安装不创建配置目录；不主动编译、授权、启停或创建 Tap。已加载服务的有限副作用为持锁健康挑战及服务快照写入。默认路径脱敏，--full-paths 提供完整恢复命令；UNKNOWN/NOT_RUNNING/DENIED/ERROR 分别表达信息缺失、未运行、当前上下文拒绝及健康异常。
- 自动化：make build、make test（44）、make integration-test（88）、make shortcut-test（64）、make diagnostic-test（37）、make check-shortcut、Zsh语法与diff检查通过，摘要见 Tests/results/automated.txt。没有将模拟命令通过当作真实系统证据。
- 真实系统：本机原先无安装/服务，本轮创建稳定路径安装。首次启动出现权限链差异（permission-startup.txt），用户配合授权后真实服务健康。重复start保持PID；第二核心返回5；SIGTERM/SIGINT/SIGKILL后服务仍加载但状态ERROR，手动start恢复；stop后未被重新拉起；未托管实际核心时status/stop/install/uninstall均拒绝；日志预填257KiB后截至61字节。详见 live-system.txt。测试服务已停止；稳定用户安装保留供后续UI/人工验收。
- 性能：真实健康PID 80490，预热10秒、300秒31次采样；CPU观察0–0.4%，RSS 7200–8816KiB，日志无增长。包含外部ps及健康挑战开销；不是精确延迟基准。前台调试轨迹的早期点未门控Tap就绪，明确排除出性能验收，新增正式门控采样入口。详见 performance.md。
- 硬件：用户确认内置触摸板、小米无线鼠标3/2.4G的上下/惯性/交替/快速及接收器重插正常，未报告明显延迟（主观）。真实verbose计数 discrete/invert=260，continuous/passthrough=484；不把会话级类型计数解释为物理HID身份。详见 hardware.txt、compatibility.md。
- 缺陷修复：测试就绪等待改为有界、mock生存上限、退出/中断清理及启动身份校验；配置symlink在chmod之前拒绝；安装器提前持核心锁拒绝前台实例，避免产生无意义事务；补齐负数Fixed Point及分数水平/flags/userData/momentum字段断言；恢复快照包含提取的runtime模块，仍能脱离载荷临时目录恢复。所有正式源码变化均通过生成器更新载荷。
- 当前仍依赖用户/设备安排：快捷指令UI宿主链、授权撤销、休眠/退出登录/重启、全屏/多桌面、实际Tap禁用恢复、其他设备、Intel及第二台Mac/iCloud。不得将未完成项标PASS；Phase 5 发布准备尚不满足，不发布v1.0、不创建标签。

- 诊断探测增加2秒截止，针对挂起 --version/--check-permission 返回 UNKNOWN 并清理子进程；工具链先检查 xcode-select 开发目录，不主动请求安装。此诊断分支补丁由 CLI 隔离测试验证；快捷指令正常切换路径未因此改变。

- UI补充：已在本机快捷指令应用保存当前完整载荷，三次Shell执行经独立状态挑战得到RUNNING→STOPPED→RUNNING。当前macOS动作名为“显示内容”；自动化不能读取结果浮窗文案，取消显示阶段后继续运行，故显示正确性/错误展示、首次UI授权链仍保留未验证，见 shortcut-ui.txt。

- 正式60秒健康门控采样已跑通，7点CPU 0–0.4%、RSS 7472–7488KiB；用户随后确认已持续滚动，记录为本机观察通过。测试结束当前服务STOPPED，无运行核心，稳定路径安装与本机已保存快捷指令保留供后续人工验收。用户随后配合撤销/恢复二进制条目，实际限定结果见下文。

- 用户最终反馈：快捷指令三次结果与滚动均正确，持续滚动采样窗口及结果浮窗文字也正确。UI显示记用户观察PASS，不再记为完全无法验证；首次UI安装授权与真正无权限UI错误展示仍未完整验收。
- 用户仅关闭 mousescrolltoggle 辅助功能条目后，当前控制入口 start=1、status=ERROR/1，旧日志多条READY未造成误报；doctor在当前调用上下文仍为AUTHORIZED，但服务PROCESS=NOT_RUNNING/TAP=ERROR。随后 shortcuts run 同一快捷指令却能启动真实健康Tap，exit=0、stdout为已开启。这是不同启动入口出现不同结果的实测记录，责任宿主/系统缓存等根因尚未定位，不能声称撤销全部授权已通过；不扩展关闭其他应用权限。撤销时服务本来STOPPED，所以运行中撤销仍未验证。证据：permission-revoked-start.txt、shortcut-permission-context.txt。
- 用户已重新打开原条目，最终确认健康后停止服务，状态STOPPED。保留稳定安装和已保存主快捷指令，无未完成事务或测试核心；未修改其他用户权限。完整最终快照见 final-state.txt、doctor-final.txt。

- 测试框架自身的失败退出及SIGTERM中断清理实测6项通过（Tests/cleanup-tests.sh）：明确验证退出码、mock子进程结束和临时目录删除。
