# Swift 核心

MouseScrollToggle.swift 包含独立 ScrollTransform 纯函数、CGEvent 适配、RecoveryBudget、前台 Event Tap 服务和 CLI。使用 TESTING 编译标志排除生产入口，供最小测试复用真实实现。无第三方包。

Fixed Point 通过 double accessor 读写，保留 16.16 小数；整数字段最小值或不能表示的 Fixed Point 反向值会使整个事件放行，避免部分修改。恢复预算为每次进程生命周期最多 3 次，不随成功恢复重置；超过后退出 4。SIGINT/SIGTERM 通过 DispatchSource 停止 RunLoop 并清理资源。

字段语义依据 [Apple 文档](https://developer.apple.com/documentation/coregraphics/cgeventfield/scrollwheeleventfixedptdeltaaxis1) 及本机 SDK CGEventTypes.h。硬件及恢复生命周期仍待实际验证。
