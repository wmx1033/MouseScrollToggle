# 架构设计基线

状态：核心已实现；控制层已实现，快捷指令自包含载荷与编排已实现，应用内执行及同步待验收。完整需求以 [需求基线](requirements.md) 为准。

## 数据与控制流

快捷指令（自包含 Swift 源码、脚本、版本）→ Zsh 安装/控制 → 用户会话 launchctl → Swift CGEventTap → 原事件返回系统。

仅 `isContinuous == 0` 的可靠离散滚动事件反转 Axis1；连续或未知事件放行。同步处理 Delta、FixedPtDelta、PointDelta 的垂直表达，默认保留 Axis2 和其余元数据。Fixed Point 访问方式与整数最小值处理必须在实现前明确并用边界测试证明，不能直接假定整数表示。

## 生命周期与状态

- NOT_INSTALLED：没有有效安装。
- STOPPED：已安装，服务未运行。
- RUNNING：服务加载、进程存活且本次进程 Event Tap 健康得到确认。
- ERROR：安装不完整、权限失败、服务异常或 Event Tap 不可用。

不能以二进制存在、PID 存在或启动命令返回 0 宣称 RUNNING。健康协议采用一次性 UUID 挑战，信号通过 launchctl 服务目标投递。启停必须串行化并防止重复实例；首次安装完成后只启动一次。

服务标识 `local.mousescrolltoggle`，操作目标为 `gui/<uid>`。plist 位于 `~/.config/mousescrolltoggle/agent.plist`，禁止放入 `~/Library/LaunchAgents/`。手动 bootstrap，关闭 bootout；允许加载期间异常恢复，但须避免权限错误造成无限重启。退出登录后不自动恢复。

Event Tap 加入 RunLoop；处理 timeout/userInput 禁用事件，恢复次数有界，超限进入 ERROR。退出信号释放资源。正常工作无高频轮询、后台网络或重复事件生成。

## 安装与升级

二进制固定在 `~/.local/bin/mousescrolltoggle`；配置目录保存 agent.plist、version、source.sha256；日志位于 `~/Library/Logs/MouseScrollToggle/`。日志必须设大小上限和轮转策略，限额为核心每次写入前检查，超过 256 KiB 截断。

相同源码跳过编译；仅版本文本变化不替换核心二进制。变更使用临时产物验证后替换，失败恢复旧二进制、配置、版本及合理的原运行状态。不得静默覆盖未知用户配置。每台 Mac 本地编译和授权，运行状态及日志不参与 iCloud 同步。

Phase 1 决策：Fixed Point 使用 double accessor 保留小数；整数最小值及无法安全反向的 Fixed Point 整事件放行。恢复限制每进程最多 3 次，超限退出。Phase 2 已实现独立健康挑战，READY 日志不作为健康依据。

Phase 2 的实际协议、锁、日志和事务策略以 [安装指南](installation.md) 为准，替代上述待定设计。

Review 修复：未加载服务但核心锁占用时为 ERROR，拒绝停止成功、卸载或替换，不对未托管 PID 发信号。破坏性操作必须持续持有核心锁，直到文件操作结束。安装事务分为准备、替换、回滚、提交；回滚失败保留完整不可消耗的旧快照及恢复脚本。细节见安装指南。


## Phase 3 载荷与点击事务

manifest.sh 的固定正式文件集合生成带引用 heredoc 的自包含 Zsh 脚本，不用 eval、网络或二进制归档。载荷以 umask 077 解包到 mktemp 私有目录，退出/INT/TERM 时清理。VERSION 保存三段数字产品版本；核心 --version 只报告协议标识，产品版本不参与核心源码哈希。

click.sh 一次获取 control.lock，复用 installer.sh 内部安装函数与 common.sh 生命周期函数，不执行重新取锁的子脚本。安装函数使用子 Shell 隔离 EXIT 清理，父进程持续持有控制锁；核心锁仍在破坏性文件操作期间持续持有。获取控制锁最多 10 秒，繁忙点击明确失败。

更新前的健康状态决定本次意图：健康运行最终关闭，其他状态尝试开启。安装成功后只执行这一意图，再确认真实最终状态。stderr 保存安装、控制、恢复提示，stdout 成功时只有一行中文结果。安装失败直接终止，不再切换。

核心摘要决定是否编译；bundle.sha256 覆盖正式运行脚本、Swift 与 VERSION，作为安装事务文件一起备份/提交/恢复。脚本变化不被核心哈希过滤，始终执行当前内嵌脚本。较低数字版本拒绝执行；同版本摘要变化明确提示，发布必须递增版本。未完成事务阻止叠加安装，恢复模块复制到配置目录备份中，脱离载荷临时目录仍可运行。

已健康运行且需要核心更新时，本次关闭意图会传给共用安装器：停止旧服务、提交已验证编译产物后保持停止，不再为了恢复运行而启动新服务后立即关闭。独立安装默认保持原运行状态；更新失败回滚仍尝试恢复原服务。
