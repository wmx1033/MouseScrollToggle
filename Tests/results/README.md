# Phase 4 本轮证据

全部采集于2026-11-16，E1=Mac15,12 / macOS27.2.1(26B131) / arm64 / Swift6.4.2 / -O。0c706b5为起点，正式文件最终摘要在environment.txt；Swift核心正文在本轮未改变，因此系统/性能/硬件证据对应同一核心。诊断字段与测试框架在采集过程中增补，最后由独立隔离回归验证，不把早期快照当作新增字段已执行的证据。

- automated.txt：实际命令及精简输出；不提交带临时路径的大量完整测试输出。
- live-system.txt：本轮真实服务生命周期、日志截断、实际未托管实例保护。
- doctor*.txt：运行、前台占锁、停止和最终状态快照；不同快照并非同一时刻。
- idle-performance.csv：预热后300秒、31点健康服务观测。
- foreground-observation.csv：前台verbose调试窗口；含启动前就绪不足的样点，**排除出性能验收**。
- scroll-performance.csv：正式健康门控60秒、7点；用户确认持续滚动窗口。时间分布由人工操作，非恒定事件率基准。
- hardware.txt：仅分类计数及用户确认，不保存逐事件或无关输入。
- shortcut-ui.txt：实际创建/保存及三次Shell执行，用户确认显示；最后安装完整性诊断字段只在CLI测试，正常开关路径未改；最终已保存最新版载荷。
- permission-startup.txt：本轮首次实际启动失败，随后用户配合授权成功，保留失败而不掩盖。
- permission-revoked*.txt：用户关闭二进制条目后控制入口的停止态/启动失败；不是运行中撤销证据。
- shortcut-permission-context.txt：同一设置动作后快捷指令入口仍能健康启动的反例。责任宿主或系统缓存的根因未定位，不能将单条目等同完整授权链撤销。
- final-state.txt：用户恢复开关后健康确认，随后STOPPED。保留稳定安装和主快捷指令，无运行测试核心/未完成事务。

不含凭据、用户路径、窗口标题或逐事件内容。未验证项目和T01–T31分层结论见../../docs/phase4-evidence.md；本机记录不代表Intel/第二台Mac/iCloud/休眠/注销/重启通过。
