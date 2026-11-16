import Foundation
import CoreGraphics
import ApplicationServices
import Darwin

struct VerticalDelta: Equatable {
    let line: Int64
    let fixed: Double
    let point: Int64
}

enum ScrollTransform {
    // Unknown and continuous inputs pass through. Unrepresentable negation
    // passes the entire event through to keep its three representations coherent.
    static func invert(continuous: Int64?, delta: VerticalDelta) -> VerticalDelta? {
        guard continuous == 0, delta.line != Int64.min, delta.point != Int64.min,
              delta.line != Int64(Int32.min), delta.point != Int64(Int32.min),
              delta.fixed.isFinite, delta.fixed > -32768, delta.fixed < 32768 else { return nil }
        return VerticalDelta(line: -delta.line, fixed: -delta.fixed, point: -delta.point)
    }

    @discardableResult static func apply(to event: CGEvent) -> Bool {
        guard event.type == .scrollWheel else { return false }
        let delta = VerticalDelta(line: event.getIntegerValueField(.scrollWheelEventDeltaAxis1),
                                  fixed: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1),
                                  point: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
        guard let result = invert(continuous: event.getIntegerValueField(.scrollWheelEventIsContinuous), delta: delta) else { return false }
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: result.line)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: result.fixed)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: result.point)
        return true
    }
}

struct RecoveryBudget {
    private(set) var attempts = 0
    mutating func consume() -> Bool {
        guard attempts < 3 else { return false }
        attempts += 1
        return true
    }
}

#if !TESTING
func report(_ message: String) {
    // launchd redirects stderr to a regular file. Bound it on every write;
    // pipes/terminals simply fail the seek and retain normal behavior.
    if let offset = try? FileHandle.standardError.seekToEnd(), offset > 262144 {
        try? FileHandle.standardError.truncate(atOffset: 0)
        try? FileHandle.standardError.seek(toOffset: 0)
    }
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

final class ScrollService {
    let state = URL(fileURLWithPath: ProcessInfo.processInfo.environment["HOME"] ?? FileManager.default.homeDirectoryForCurrentUser.path).appendingPathComponent(".config/mousescrolltoggle")
    var lockFD: Int32 = -1
    var tap: CFMachPort?
    var source: CFRunLoopSource?
    var signals: [DispatchSourceSignal] = []
    var recovery = RecoveryBudget()
    var exitCode: Int32 = 0
    let verbose: Bool
    init(verbose: Bool) { self.verbose = verbose }

    func stop(error: String? = nil) {
        if let error { report("ERROR: " + error); exitCode = 4 }
        CFRunLoopStop(CFRunLoopGetMain())
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent> {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            guard AXIsProcessTrusted(), recovery.consume(), let tap else {
                stop(error: "Event Tap 无法恢复或权限已撤销，请重新授权后重试")
                return .passUnretained(event)
            }
            CGEvent.tapEnable(tap: tap, enable: true)
            if !CGEvent.tapIsEnabled(tap: tap) { stop(error: "Event Tap 恢复失败") }
        } else if type == .scrollWheel {
            let inverted = ScrollTransform.apply(to: event)
            if verbose {
                let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
                report("event=scroll continuous=\(continuous) classification=\(continuous == 0 ? "discrete" : "continuous") action=\(inverted ? "invert" : "passthrough")")
            }
        }
        return .passUnretained(event)
    }

    func run() -> Int32 {
        do { try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
        catch { report("启动失败：无法创建运行目录：\(error)"); return 5 }
        lockFD = open(state.appendingPathComponent("core.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { report("启动失败：已有核心实例或无法取得锁"); return 5 }
        defer { close(lockFD) }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            report("启动失败：未获得辅助功能权限\n请打开：系统设置 → 隐私与安全性 → 辅助功能；授权后重试")
            return 2
        }
        guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: CGEventMask(1) << CGEventType.scrollWheel.rawValue,
            callback: { _, type, event, context in
                guard let context else { return .passUnretained(event) }
                return Unmanaged<ScrollService>.fromOpaque(context).takeUnretainedValue().handle(type: type, event: event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            report("启动失败：无法创建 Event Tap，请检查辅助功能权限")
            return 3
        }
        tap = created
        defer {
            for signalSource in signals { signalSource.cancel() }
            CGEvent.tapEnable(tap: created, enable: false)
            if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
            CFMachPortInvalidate(created)
        }
        guard let runSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0) else {
            report("启动失败：无法创建 RunLoop source")
            return 3
        }
        source = runSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runSource, .commonModes)
        for number in [SIGINT, SIGTERM, SIGUSR1] {
            signal(number, SIG_IGN)
            let signalSource = DispatchSource.makeSignalSource(signal: number, queue: .main)
            signalSource.setEventHandler { [weak self] in
                guard let self else { return }
                if number == SIGUSR1 {
                    let request = self.state.appendingPathComponent("request")
                    guard let nonce = try? String(contentsOf: request, encoding: .utf8),
                          nonce.count == 37, let tap = self.tap else { return }
                    let healthy = AXIsProcessTrusted() && CGEvent.tapIsEnabled(tap: tap)
                    let response = "\(getpid()) \(healthy ? "READY" : "ERROR") \(nonce)"
                    try? Data(response.utf8).write(to: self.state.appendingPathComponent("response"), options: .atomic)
                } else { self.stop() }
            }
            signalSource.resume()
            signals.append(signalSource)
        }
        CGEvent.tapEnable(tap: created, enable: true)
        guard CGEvent.tapIsEnabled(tap: created) else { return 3 }
        try? Data("\(getpid())".utf8).write(to: state.appendingPathComponent("ready-pid"), options: .atomic)
        defer { try? FileManager.default.removeItem(at: state.appendingPathComponent("ready-pid")) }
        report("READY: Event Tap 已启用（前台运行，Ctrl-C 停止）")
        CFRunLoopRun()
        return exitCode
    }
}

@main enum Main {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if args == ["--help"] {
            print("用法：mousescrolltoggle [--verbose | --check-permission | --version | --help]")
            return
        }
        if args == ["--version"] { print("1.0.0-dev"); return }
        if args == ["--check-permission"] {
            let trusted = AXIsProcessTrusted()
            print(trusted ? "辅助功能权限：已授权" : "辅助功能权限：未授权")
            exit(trusted ? 0 : 2)
        }
        guard args.isEmpty || args == ["--verbose"] else { report("未知参数，请使用 --help"); exit(64) }
        exit(ScrollService(verbose: args == ["--verbose"]).run())
    }
}
#endif
