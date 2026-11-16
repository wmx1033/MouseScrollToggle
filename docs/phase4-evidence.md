# Phase 4 验收证据索引

E1：2026-11-16，Mac15,12，macOS 27.2.1 (26B131)，arm64，Swift 6.4.2，-O。本轮以 0c706b5 为起点；最终源码身份见 Tests/results/environment.txt。自动化均使用隔离 HOME、独立服务名；真实系统使用新建的稳定路径安装，不替换已有用户安装。下表“PASS（模拟）”只适用于明确写出的模拟层，不能代表硬件或真实 launchctl 通过。完整原始操作规范仍见 acceptance-tests.md。

证据文件：A=Tests/results/automated.txt（本轮执行摘要及命令）、L=Tests/results/live-system.txt、P=Tests/results/idle-performance.csv、H=Tests/results/hardware.txt、D=Tests/results/doctor.txt。测试脚本为可复查步骤；表中未验证项目给出待执行操作，不能当作通过。缺陷列“无新增”仅指已运行的层，不代表未运行层无缺陷。

| 用例/需求 | 层与环境 | 本轮步骤 | 预期 → 实际 | 结果 | 证据 | 缺陷/复测 |
|---|---|---|---|---|---|---|
| T01 F01 鼠标上滚 | 硬件 E1 | 用户鼠标上滚，对照关闭状态 | 仅垂直反转 → 用户确认正常 | PASS（用户观察） | H/compatibility.md | 待测 |
| T02 F01 鼠标下滚 | 硬件 E1 | 用户鼠标下滚 | 仅垂直反转 → 用户确认正常 | PASS（用户观察） | H | 待测 |
| T03 F02 触摸板向上 | 硬件 E1 | 双指上滑 | 自然方向不变 → 用户确认正常 | PASS（用户观察） | H | 待测 |
| T04 F02 触摸板向下 | 硬件 E1 | 双指下滑 | 自然方向不变 → 用户确认正常 | PASS（用户观察） | H | 待测 |
| T05 F02 惯性 | 硬件 E1 | 双指快速滑动后释放 | 惯性不变 → 用户确认正常 | PASS（用户观察） | H | 待测 |
| T06 F01/F02 交替 | 硬件 E1 | 交替鼠标/触摸板 | 各自正确，无重复事件 → 用户确认正常，verbose 两类均观察到 | PASS（用户观察） | H | 待测 |
| T07 F03/F05 开启 | 真实系统 E1 / UI | control start + doctor；实际快捷指令待创建 | 新挑战健康 → 本轮应用内三次Shell执行开/关/开且独立健康验证，结果浮窗由用户确认三次文案正确 | PASS（真实系统/UI及用户观察） | D；L 待补 | 初次启动权限失败，重试成功 |
| T08 F03 关闭 | 真实系统 E1 / UI | control stop 后 print/status；UI 点击待测 | 服务/核心结束 → 真实 stop 后 STOPPED，1秒内未重启；应用内第二次执行也STOPPED，浮窗文案由用户确认正确 | PASS（真实系统/UI及用户观察） | L | 待测 |
| T09 F03 快速点击 | 模拟 E1 / UI | shortcut-tests 四次并发完整点击 | 两开两关，无死锁 → 自动化通过，UI 待测 | PASS（模拟）；UI 未验证 | A；shortcut-tests.sh | 无新增 |
| T10 F04/F05/F06 首装 | 模拟/真实系统 E1 / UI | 隔离首次载荷执行；稳定路径本机安装启动 | 首装只开一次 → 自动化通过，本机启动健康；UI/Intel 待测 | PASS（本机/模拟）；UI/Intel 未验证 | A、D | 权限初次失败已保留记录 |
| T11 F04/F09 幂等安装 | 模拟 E1 | inode/mtime、构建次数断言 | 不重复编译/替换 → 通过 | PASS（模拟） | A；integration/shortcut-tests.sh | 无新增 |
| T12 F10 卸载 | 模拟 E1 | 运行中卸载、重复卸载、未知文件保护 | 停止并仅删自有文件 → 通过；稳定安装为人工验收保留 | PASS（模拟） | A；integration-tests.sh | 无新增 |
| T13 F08 重启 | 真实系统 E1 | 用户安排重启后查询 | 不自动运行 → 未执行重启 | 未验证 | compatibility.md | 不主动中断用户工作 |
| T14 F06/F07 第二台Mac | 跨设备 | 同步后独立编译授权 | 状态互相独立 → 无第二台设备证据 | BLOCKED | Shortcuts/README.md | 缺设备 |
| T15 F05 撤销权限 | 真实系统 E1 | 用户撤销后 doctor/status，再恢复 | DENIED/ERROR → 用户关闭二进制条目后，控制入口启动失败/ERROR；快捷指令上下文仍能健康启动 | 部分PASS；完整链及运行中撤销未验证 | permission-revoked-start.txt、shortcut-permission-context.txt | 用户已恢复开关，不扩大撤销其他宿主 |
| T16 F09 回滚 | 模拟 E1 | 启动/bootout/超时/恢复文件/旧服务恢复故障注入 | 完整快照保留且可执行恢复 → 通过 | PASS（模拟） | A；integration/shortcut-tests.sh | 无新增 |
| T17 F01/F02 纯函数 | 纯函数/CGEvent E1 | event-tests 边界/连续/未知/零/正负 | 安全取反/放行 → 通过 | PASS（合成） | A；event-tests.swift | 增补负小数 Fixed Point |
| T18 F01/F12 字段 | 合成CGEvent E1 | 分数水平、三种垂直、flags/userData/phase/momentum | 垂直一致，其余保持 → 通过 | PASS（合成） | A；event-tests.swift | 补齐水平小数断言 |
| T19 F05 Tap恢复 | 纯函数 / 真实系统 | 预算三次后耗尽；实际禁用需安全条件 | 有界恢复 → 预算通过，真实禁用未注入 | BLOCKED（真实Tap） | A；event-tests.swift | 不把预算测试当恢复实测 |
| T20 F05 健康退出 | 模拟/真实系统 E1 | 陈旧响应、暂停核心、SIGINT/TERM、锁互通 | 不误报健康并释放资源 → 真实信号退出与第二实例拒绝通过 | PASS（真实系统/模拟） | A、L | 无新增 |
| T21 F08 退出登录 | 真实系统 E1 | 用户注销再登录 | 不自动启动 → 尚未注销 | 未验证 | compatibility.md | 不主动注销 |
| T22 F01/F02 休眠 | 硬件/真实系统 | 用户安排休眠唤醒，再测滚动 | 正常或明确异常 → 未安排 | 未验证 | compatibility.md | 不主动休眠 |
| T23 F01 重连 | 硬件 E1 | 用户重插接收器/USB、蓝牙重连 | 分类及方向恢复 → 用户确认2.4G重插正常；USB/蓝牙未测 | PASS（2.4G用户观察）；其他未验证 | H | 其他连接设备缺失 |
| T24 F01/F02 高频 | 硬件 E1 | 快速滚动、全屏/多桌面 | 无双倍/循环/持续丢事件 → 用户确认快速滚动正常；全屏/多桌面未测 | PASS（快速用户观察）；其他未验证 | H | 待测 |
| T25 F04/F05 安装失败 | 模拟/文件系统 E1 | 无工具链、路径阻塞、只读bin目录、编译失败 | 中文错误、不假报成功、旧快照可恢复 → 通过 | PASS（隔离） | A；doctor/integration-tests.sh | 新增目录错误中文说明 |
| T26 F09 版本摘要 | 模拟 E1 | 版本/核心/脚本变化及旧载荷 | 仅核心变化编译、拒绝低版本 → 通过 | PASS（模拟） | A；shortcut-tests.sh | 无新增 |
| T27 F11 诊断隐私 | 模拟/真实系统 E1 | doctor 多状态、--doctor载荷、日志限额 | 不弹权限/不建Tap、默认脱敏 → 诊断通过；预填257KiB后真实日志截至61字节 | PASS（诊断/真实日志） | A、D、L | 修复缺失诊断入口 |
| T28 F01/F02 性能 | 真实系统 E1 | 预热10秒，ps每10秒采300秒；滚动另测 | 健康进程CPU/RSS与日志 → 300秒31点及60秒7点健康门控通过，用户确认滚动窗口 | PASS（本机观察） | P | 不测退出进程，不保证无延迟 |
| T29 F03/F05 异常退出 | 真实系统 E1 / 模拟 | SIGKILL→ERROR→手动start→stop | 无自动重启，手动可恢复 → 真实 SIGKILL 后ERROR，手动start通过 | PASS（真实系统/模拟） | A、L | 无新增 |
| T30 F04/F09 配置保护 | 模拟 E1 | 修改plist再安装 | 拒绝覆盖，保留修改 → 通过 | PASS（模拟） | A；integration-tests.sh | 无新增 |
| T31 F07 载荷完整 | 模拟 E1 / UI / 跨设备 | 隐藏仓库执行载荷、摘要比对 | 自包含，无下载/二进制 → 自动化通过，UI/第二台未验 | PASS（模拟）；跨设备BLOCKED | A；shortcut-tests.sh | 无新增 |

当前缺陷：P2 诊断缺失、测试清理/无界等待、配置目录符号链接 chmod 顺序、未托管实例拒绝过晚、前台采样未门控就绪、分数水平字段断言缺口，均已修复并增加回归或正式门控入口；没有凭证可将权限链差异归因为核心逻辑错误。真实授权、硬件与 UI 的未完成项目是验收缺口，不能被模拟 PASS 抵消。Phase 5 的发布准备条件尚不满足。

UI补充证据见 Tests/results/shortcut-ui.txt：已实际保存完整当前载荷，三次应用内Shell运行的服务效果经独立实时挑战确认；“显示内容”浮窗文案随后由用户确认正确；错误场景的 UI 展示及首次UI授权链仍未完整验收。

权限链限定：用户仅撤销 mousescrolltoggle 条目时，当前控制入口失败，但 shortcuts run 实际仍能启动健康 Tap。该反例已保存，不声明关闭一个条目等于撤销全部宿主权限。本轮撤销时服务原本已停止，不将“撤销后重新启动”冒充“运行中撤销”。用户已恢复原开关；最终状态见 final-state.txt。
