// SPDX-License-Identifier: MPL-2.0
// Motion tokens: Reduce Motion is honoured by every token that is not direct manipulation (docs/05-design-system/02-motion-e-fisica.md §5).
import SwiftUI
import TimbreDesignSystem

@main
struct TimbreTokensTestRunner {
    static func fail(_ msg: String) -> Never { fputs("FAIL: \(msg)\n", stderr); exit(1) }
    static func expect(_ ok: Bool, _ msg: String) { if !ok { fail(msg) } }

    static func main() {
        print("[TimbreTokensTests] Running motion token tests...")
        let fade = TimbreMotion.reducedFadeForTests

        // Computed tokens: rebuild the list each time, after the setting changed.
        func decorative() -> [(String, Animation)] { [
            ("enter", TimbreMotion.enter), ("standard", TimbreMotion.standard), ("exit", TimbreMotion.exit), ("inOut", TimbreMotion.inOut),
            ("pressOut", TimbreMotion.pressOut), ("fade", TimbreMotion.fade), ("fadeOut", TimbreMotion.fadeOut), ("tab", TimbreMotion.tab),
            ("snappy", TimbreMotion.snappy), ("smooth", TimbreMotion.smooth), ("morph", TimbreMotion.morph),
            ("notchOpen", TimbreMotion.notchOpen), ("notchClose", TimbreMotion.notchClose), ("notchPop", TimbreMotion.notchPop),
        ] }

        TimbreMotion.reducedOverride = true
        for (name, a) in decorative() { expect(a == fade, "Reduce Motion: '\(name)' must become the 120 ms fade, not a spring or a travelling curve") }
        expect(TimbreMotion.staggerItem == 0 && TimbreMotion.staggerMaxTotal == 0, "Reduce Motion: staggers vanish")
        expect(TimbreMotion.dismissFollow != fade && TimbreMotion.responsive != fade, "Following the pointer is direct manipulation: it keeps tracking under Reduce Motion")

        TimbreMotion.reducedOverride = false
        for (name, a) in decorative() { expect(a != fade, "Normal motion: '\(name)' must not collapse into the reduced fade") }
        expect(TimbreMotion.staggerItem == 0.035 && TimbreMotion.staggerMaxTotal == 0.35, "Normal motion: stagger is 35 ms, 350 ms at most")
        expect(TimbreMotion.notchOpen != TimbreMotion.notchClose && TimbreMotion.enter != TimbreMotion.exit, "Opening and closing differ (asymmetry)")
        TimbreMotion.reducedOverride = nil
        print("  [PASS] TimbreMotion honours Reduce Motion token by token (fades only; pointer-following springs exempt)")
        print("[TimbreTokensTests] ALL PASSED")
    }
}
