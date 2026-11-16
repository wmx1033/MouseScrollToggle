# 安装、使用与卸载

前置条件：macOS 图形用户会话，Swift Command Line Tools，普通用户。稳定二进制路径 ~/.local/bin/mousescrolltoggle。

## Phase 2 实现（2026-11-16）

安装：`./Scripts/install.sh`（或 `make install`），只安装，不开启。控制：`./Scripts/control.sh start|stop|toggle|status`。卸载：`./Scripts/uninstall.sh`（或 `make uninstall`）。快捷指令自包含载荷已实现，创建及同步步骤见 ../Shortcuts/README.md。

stdout 首词为稳定状态：NOT_INSTALLED、STOPPED、RUNNING、ERROR，后接中文说明。status：未安装返回 3，停止/健康运行返回 0，异常返回 1；操作成功返回 0，普通失败 1，未安装启动 3，参数错误 64，锁等待超时 75，配置冲突或不安全路径 78。核心保留 0/2/3/4/64，新增 5 表示单实例锁或运行目录失败。错误细节输出 stderr。

所有控制操作（包括 status）使用同一个持久文件的内核锁，最多等 10 秒；进程退出由内核释放，无陈旧锁删除竞态。core.lock 使用 Swift lockf 与 Zsh flock 互通的 POSIX 文件锁，覆盖直接运行和 launchd 运行；两个锁文件在卸载后保留，不能在持有者或等待者存在时删除。运行目录 700，新文件 umask 077。不要手动删除锁来解决并发问题。

健康检查：从 launchctl print 取得正确程序路径和 PID，确认进程存活与就绪 PID，再写入 UUID 挑战并通过 launchctl kill 向当前服务发送 SIGUSR1。核心在主 RunLoop 检查当前 AX 权限与 tapIsEnabled，返回 PID、结果和本次 UUID。每次查询最多等待 1 秒，启动最多尝试 5 轮；旧响应、PID 重用或旧 READY 日志均不能通过新挑战。正常运行无轮询。ready-pid 只是查询门槛，不是健康证据；响应文件允许残留但不能冒充新挑战。Tap 禁用每进程最多恢复三次，超限退出；SIGINT/SIGTERM 停 RunLoop、释放 Tap 与锁。

服务位于 gui/<uid>，plist 只保存在 ~/.config/mousescrolltoggle/agent.plist，RunAtLoad 仅在手动 bootstrap 时启动，不创建 LaunchAgents。没有 KeepAlive：异常退出保留已加载服务供诊断，status 报 ERROR，用户 start 会 bootout 后重新加载。这是保守的手动恢复策略，不自动重启权限/Tap 失败。stop 使用 bootout 后有界确认服务消失并取得核心锁（不依赖旧 PID），不用可能无限阻塞的 --wait。登录退出、重新登录行为仍需人工验收。

源码 SHA-256 相同跳过编译与二进制替换；版本文本更新不替换二进制。临时编译及 --version 验证后提交产物。managed.sha256 记录生成 plist 的摘要，配置有修改时返回 78，请先备份并移走配置再安装/卸载，不静默覆盖。plist 用系统 plutil 生成，支持空格与 XML 特殊字符。更新前备份二进制、plist、版本及摘要；原服务已加载时更新后重新启动并验证，失败恢复全部旧产物并尝试恢复旧服务；恢复失败明确报告，不假报成功。未加载服务更新后仍停止。事务处理命令失败，不保证断电/SIGKILL 下跨文件原子性。

日志：~/Library/Logs/MouseScrollToggle/stdout.log、stderr.log。核心每次写 stderr 前检查文件偏移，超过 256 KiB 清空并从头写；单条信息可能略超上限，无历史轮转，stdout 正常服务不写。普通模式无逐事件日志。不能限制第三方替换核心的输出；详细模式也使用此上限。

卸载先停止，配置冲突则保留文件并报错；只删除明确列出的产物和两个日志，保留未知文件及锁。不删除系统权限记录，用户可在系统设置移除。核心锁被未托管实例占用时，status 为 ERROR，stop、install、uninstall 返回 1，提示先关闭前台实例。不会向其 PID 发送信号，不会删除/替换文件。脚本取得核心锁后持续持有至文件操作结束，启动前才释放；期间新核心会返回 5。

## Review 修复：事务与人工恢复

事务阶段记录在 `.install.XXXXXX/phase`：PREPARED（完整快照与恢复脚本已保存）、REPLACING、ROLLING_BACK、COMMITTED。提交点是全部文件写入成功，且原已加载服务已恢复健康。没有服务时安装仍保持停止。生命周期函数返回错误给安装协调逻辑，不深层 exit。

只有提交成功或文件与原服务完整恢复后才删除备份。bootout 失败、停止超时、恢复文件失败、恢复旧服务失败均保留完整 old-binary、old-agent.plist、old-version、old-source.sha256、old-managed.sha256，以及 expected-home、was-loaded、phase、common.sh 和 recover.sh。恢复使用复制，不消耗旧快照；文件恢复中途失败时不启动核心，安装可能暂时不一致，禁止宣称完成。只有确认服务卸载并持续持有核心锁后才能恢复文件，避免覆盖仍运行的新版本。

失败时 stderr 输出备份路径及带 Shell 转义的 `/bin/zsh <备份目录>/recover.sh`。在同一用户、同一 HOME 下先关闭前台实例，解决权限或文件系统错误，再原样执行该命令；恢复脚本会取得控制锁、停止服务、取得核心锁、恢复全部文件，并按 was-loaded 决定是否恢复服务。失败保留备份供再次重试；成功才删除。不要手工删除锁或备份，不要在失败未恢复时继续安装另一版本。若需要手工取回文件，old-* 是完整快照，必须先确认核心停止，不能在活跃进程期间直接复制。

陈旧 ready-pid/response 不触发直接 kill。健康信号交给 launchctl 按服务身份投递，UUID 响应仍必须匹配当前查询；未托管实例只依据内核锁判定“不能安全操作”，不尝试猜测 PID 身份。断电/SIGKILL 不保证自动恢复；已准备的备份保留，可使用恢复脚本。


## Phase 3 一次点击

按 [快捷指令指南](../Shortcuts/README.md) 创建 Mouse Scroll Toggle。运行载荷会先检查 Darwin、arm64/x86_64 和用户会话、未完成事务与本机版本，再执行安装器、单次切换、最终健康确认。若原先健康运行，更新成功后本次最终关闭；其他状态尝试开启。更新失败立即返回，不执行切换。首次安装不会先启动再关闭。缺权限时 stderr 提供系统设置指引，授权后重试；更新回滚失败时先按恢复命令处理。

每次安装都计算 bundle.sha256 并纳入旧快照。三段数字 VERSION 为产品版本；0.3.0 是开发阶段版本。核心 --version 是 core-protocol=1，源码未变时仅改 VERSION 不替换核心。快捷指令拒绝旧数字版本降级；同版本内容不同会提示再更新，发布应递增版本。直接 install.sh 是显式本地安装入口，不套用快捷指令的拒绝降级策略。Phase 2 无 bundle.sha256 的 1.0.0-dev 安装可迁移。

检测到 `.install.*/phase` 即拒绝新安装/点击，打印恢复命令。旧快照现在也包含 old-bundle.sha256。恢复脚本与 common.sh 已独立保存到 ~/.config/mousescrolltoggle/.install.*，载荷解包清理不会使其失效。新的安装器为内部函数，调用者持有控制锁；未完成事务检查发生于新事务创建之前。

已健康运行且需要核心更新时，本次关闭意图会传给共用安装器：停止旧服务、提交已验证编译产物后保持停止，不再为了恢复运行而启动新服务后立即关闭。独立安装默认保持原运行状态；更新失败回滚仍尝试恢复原服务。
