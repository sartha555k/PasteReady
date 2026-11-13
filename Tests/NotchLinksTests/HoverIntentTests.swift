@main
struct HoverIntentTests {
    static func main() {
        var hover = HoverIntent()
        precondition(hover.sample(trigger: "built-in"))
        precondition(!hover.sample(trigger: "built-in"))
        print("PASS: first entry opens immediately with no settling delay")

        hover = HoverIntent()
        precondition(!hover.sample(trigger: nil))
        precondition(hover.sample(trigger: "built-in"))
        for _ in 0..<100 { precondition(!hover.sample(trigger: "built-in")) }
        print("PASS: fast landing stays open while cursor rests behind camera")

        hover = HoverIntent()
        for _ in 0..<100 { precondition(!hover.sample(trigger: nil)) }
        precondition(hover.sample(trigger: "built-in"))
        print("PASS: slow approach opens on the same first entry")

        hover.blockUntilExit()
        for _ in 0..<100 { precondition(!hover.sample(trigger: "built-in")) }
        precondition(!hover.sample(trigger: nil))
        precondition(hover.sample(trigger: "built-in"))
        print("PASS: dismissal prevents loops but exit/reentry opens immediately")

        hover = HoverIntent()
        precondition(hover.sample(trigger: "built-in"))
        precondition(hover.sample(trigger: "external"))
        precondition(!hover.sample(trigger: "external"))
        print("PASS: entry into a different display trigger is independent")

        hover.blockUntilExit()
        precondition(!hover.sample(trigger: nil))
        precondition(hover.sample(trigger: "built-in"))
        print("PASS: exit observed during closing rearms the next fast entry")
        print("All 6 entry-trigger checks passed.")
    }
}
