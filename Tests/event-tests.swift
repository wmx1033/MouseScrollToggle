import Foundation
import CoreGraphics

@main enum EventTests {
    static func main() {
        var checks = 0
        func check(_ condition: Bool, _ label: String) {
            guard condition else { fatalError("FAIL: \(label)") }
            checks += 1
        }
        for continuous: Int64? in [nil, 1, -1, 2] {
            check(ScrollTransform.invert(continuous: continuous, delta: .init(line: 1, fixed: 1.5, point: 10)) == nil, "continuous/unknown")
        }
        for value: Int64 in [-100, -1, 0, 1, 100, Int64.max] {
            check(ScrollTransform.invert(continuous: 0, delta: .init(line: value, fixed: 1.5, point: value)) == .init(line: -value, fixed: -1.5, point: -value), "signed delta")
        }
        for fixed: Double in [-32767.5, -1.75, 0, 0.25, 32767.5] {
            check(ScrollTransform.invert(continuous: 0, delta: .init(line: 1, fixed: fixed, point: -2)) == .init(line: -1, fixed: -fixed, point: 2), "signed fractional fixed point")
        }
        for value in [Int64.min, Int64(Int32.min)] {
            check(ScrollTransform.invert(continuous: 0, delta: .init(line: value, fixed: 1, point: 1)) == nil, "line minimum")
            check(ScrollTransform.invert(continuous: 0, delta: .init(line: 1, fixed: 1, point: value)) == nil, "point minimum")
        }
        for value: Double in [-32768, 32768, .infinity, .nan] {
            check(ScrollTransform.invert(continuous: 0, delta: .init(line: 1, fixed: value, point: 1)) == nil, "fixed bounds")
        }
        for continuous: Int64 in [0, 1] {
            let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 3, wheel2: 7, wheel3: 0)!
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: continuous)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 1.5)
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 12)
            event.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -2.75)
            event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 1)
            event.setIntegerValueField(.eventSourceUserData, value: 42)
            event.flags = [.maskShift]
            let horizontalFixed = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
            let horizontal = [CGEventField.scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis2].map { event.getIntegerValueField($0) }
            let timestamp = event.timestamp
            check(ScrollTransform.apply(to: event) == (continuous == 0), "classification")
            let sign: Int64 = continuous == 0 ? -1 : 1
            check(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == sign * 3, "line")
            check(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) == Double(sign) * 1.5, "fixed fractional conversion")
            check(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == sign * 12, "point")
            check(horizontal == [CGEventField.scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis2].map { event.getIntegerValueField($0) }, "horizontal unchanged")
            check(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2) == horizontalFixed, "fractional horizontal preserved")
            check(event.flags == [.maskShift] && event.getIntegerValueField(.eventSourceUserData) == 42 && event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 1, "flags/user data/momentum preserved")
            check(event.timestamp == timestamp && event.getIntegerValueField(.scrollWheelEventScrollPhase) == 2, "metadata")
        }
        let other = CGEvent(source: nil)!
        check(!ScrollTransform.apply(to: other), "non-scroll")
        var budget = RecoveryBudget()
        for _ in 0..<3 { check(budget.consume(), "recovery allowed") }
        check(!budget.consume(), "bounded recovery")
        print("PASS: \(checks) checks (synthetic events only; no hardware claim)")
    }
}
