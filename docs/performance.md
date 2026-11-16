# Phase 4 性能记录

E1：Mac15,12，macOS 27.2.1 (26B131)，arm64，Swift 6.4.2，-O。本轮稳定路径核心；完整源身份见 Tests/results/environment.txt。

空闲观察：Tests/results/idle-performance.csv。PID 80490，预热10秒，每10秒采样一次，0–300秒共31点；每点前通过 control status 确认真实 Tap 健康。macOS ps 的近期 %CPU 范围0–0.4%，RSS 7200–8816 KiB（约7.03–8.61 MiB），stderr 从313到313字节，无增长。按要求请用户尽量不滚动；不声称具有实验室输入隔离。ps 和健康挑战是外部观察工具，其开销包含在测量情境中，核心平时没有10秒轮询。采样不是精确逐事件延迟基准，不能从低CPU推断无延迟。

前台 verbose 窗口：Tests/results/foreground-observation.csv，0–125秒26点。这份调试轨迹在进程刚创建时开始，首点可能尚未创建 Tap，因此**不作为符合健康门槛的性能验收数据**。修复后的正式测量入口 Tests/measure-performance.sh 仅对已健康服务采样、预热10秒，并在每点确认健康且PID未变。保留此轨迹说明观察工具缺陷，避免把启动时几百KiB RSS当作正常常驻内存。

物理滚动结果由用户反馈：本轮鼠标与触摸板交替/快速滚动无明显延迟（主观）。该结果不是定量端到端延迟；真实持续滚动CPU/RSS另由正式入口采60秒，不能把前台未门控的窗口混入已验证结果。无需针对本轮正常空闲数据进行过度优化，也没有伪造优化前后对比。

复测命令：确认服务 RUNNING 后执行 `Tests/measure-performance.sh --live 300 idle`，另在用户持续滚动时执行 `Tests/measure-performance.sh --live 60 scroll`。入口只观察，不启停；健康丢失或实例变化即终止。普通自动化测试不会运行长时间采样。10 MiB 是建议目标，本轮单机观察不能代表所有设备、架构和系统版本。

补充：正式入口已实际执行60秒 scroll 模式，见 Tests/results/scroll-performance.csv，7点均通过健康/同PID门控；CPU 观察0–0.4%、RSS 7472–7488KiB。用户随后确认已持续滚动，因此记为本机持续滚动窗口通过（包含人工操作时间分布的不确定性，非恒定事件率基准）。
