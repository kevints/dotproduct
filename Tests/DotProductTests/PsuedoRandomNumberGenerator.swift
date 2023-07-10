import DotProductRNG

struct DPRNG : RandomNumberGenerator {
    private class Box {
        private var rawValue: OpaquePointer!
        init(rawValue: OpaquePointer? = nil) {
            if let rawValue {
                self.rawValue = rawValue
            } else {
                self.rawValue = DotProductRNG_New()
            }
        }
        deinit {
            DotProductRNG_Delete(rawValue)
        }
        func seed(_ value: UInt64) {
            DotProductRNG_Seed(rawValue, value)
        }
        func unsafeCopy() -> OpaquePointer! {
            DotProductRNG_Copy(rawValue)
        }
        func copy() -> Box {
            .init(rawValue: unsafeCopy())
        }
        func next() -> UInt64 {
            DotProductRNG_Next(rawValue)
        }
    }
    private var box: Box
    
    init(seed: UInt64) {
        box = Box()
        box.seed(seed)
    }
    mutating func next() -> UInt64 {
        if !isKnownUniquelyReferenced(&box) {
            box = box.copy()
        }
        return box.next()
    }
}

