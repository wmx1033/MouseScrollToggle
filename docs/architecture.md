# 架构设计基线

状态：核心已实现；控制层已实现，快捷指令仍为设计。完整需求以 [需求基线](requirements.md) 为准。

## 数据与控制流

快捷指令（自包含 Swift 源码、脚本、版本）→ Zsh 安装/控制 → 用户会话 launchctl → Swift CGEventTap → 原事件返回系统。

仅 `isContinuous == 0` 的可靠离散滚动事件反转 Axis1；连续或未知事件放行。同步处理 Delta、FixedPtDelta、PointDelta 的垂直表达，默认保留 Axis2 和其余元数据。Fixed Point 访问方式与整数最小值处理必须在实现前明确并用边界测试证明，不能直接假定整数表示。

## 生命周期与状态

- NOT_INSTALLED：没有有效安装。
- STOPPED：已安装，服务未运行。
- RUNNING：服务加载、进程存活且本次进程 Event Tap 健康得到确认。
- ERROR：安装不完整、权限失败、服务异常或 Event Tap 不可用。

不能以二进制存在、PID 存在或启动命令返回 0 宣称 RUNNING。健康协议需防止旧进程状态残留，具体机制待 Phase 2 确定。启停必须串行化并防止重复实例；首次安装完成后只启动一次。

服务标识 `local.mousescrolltoggle`，操作目标为 `gui/<uid>`。plist 位于 `~/.config/mousescrolltoggle/agent.plist`，禁止放入 `~/Library/LaunchAgents/`。手动 bootstrap，关闭 bootout；允许加载期间异常恢复，但须避免权限错误造成无限重启。退出登录后不自动恢复。

Event Tap 加入 RunLoop；处理 timeout/userInput 禁用事件，恢复次数有界，超限进入 ERROR。退出信号释放资源。正常工作无高频轮询、后台网络或重复事件生成。

## 安装与升级

二进制固定在 `~/.local/bin/mousescrolltoggle`；配置目录保存 agent.plist、version、source.sha256；日志位于 `~/Library/Logs/MouseScrollToggle/`。日志必须设大小上限和轮转策略，具体限额待实现。

相同源码跳过编译；仅版本文本变化不替换核心二进制。变更使用临时产物验证后替换，失败恢复旧二进制、配置、版本及合理的原运行状态。不得静默覆盖未知用户配置。每台 Mac 本地编译和授权，运行状态及日志不参与 iCloud 同步。

Phase 1 决策：Fixed Point 使用 double accessor 保留小数；整数最小值及无法安全反向的 Fixed Point 整事件放行。恢复限制每进程最多 3 次，超限退出。当前仅提供前台 READY 初始化确认，持续健康协议留待 Phase 2。

Phase 2 的实际协议、锁、日志和事务策略以 [安装指南](installation.md) 为准，替代上述待定设计。
