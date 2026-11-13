/// Opens on entry at any pointer speed. A dismissed panel rearms only after exit.
struct HoverIntent {
    private var candidate: String?
    private var fired = false
    private var blocked = false

    mutating func blockUntilExit() {
        candidate = nil
        fired = false
        blocked = true
    }
    mutating func sample(trigger: String?) -> Bool {
        guard let trigger else {
            candidate = nil
            fired = false
            blocked = false
            return false
        }
        guard !blocked else { return false }
        if candidate != trigger { candidate = trigger; fired = false }
        guard !fired else { return false }
        fired = true
        return true
    }
}
