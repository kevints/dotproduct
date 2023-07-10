import CXXDotProduct

public func validate_progresses3(_ progresses: UnsafeBufferPointer<UInt8>, _ weights: UnsafeBufferPointer<Float>) -> Bool {
    progresses.count == weights.count
        // TODO: zero pad to alignment of 64 - it won't change the result precondition (progresses.count % 64 == 0)
        && UInt(bitPattern: progresses.baseAddress!) % UInt(MemoryLayout<SIMD64<UInt8>>.alignment) == 0
        && UInt(bitPattern: weights.baseAddress!) % UInt(MemoryLayout<SIMD64<Float>>.alignment) == 0
}

public func process_progresses3(_ progresses: UnsafeBufferPointer<UInt8>, _ weights: UnsafeBufferPointer<Float>) -> ProgressResult {
    assert(validate_progresses3(progresses, weights))
    var result = ProgressResult()
    progresses.withMemoryRebound(to: SIMD64<UInt8>.self) { simdProgresses in
        weights.withMemoryRebound(to: SIMD64<Float>.self) { simdWeights in
            for i in simdProgresses.indices {
                let progress = simdProgresses[i]
                let weight = simdWeights[i]
            
                let floatProgress = SIMD64<Float>(progress)
                result.weighted_progress += (floatProgress * weight).sum()
                result.raw_progress += floatProgress.sum()
            }
        }
    }
    return result
}

public func validate_progresses4(_ records: UnsafeBufferPointer<ProgressRecord>) -> Bool {
    UInt(bitPattern: records.baseAddress!) % UInt(MemoryLayout<SIMD64<UInt64>>.alignment) == 0
    && MemoryLayout<ProgressRecord>.offset(of: \.progress) == 0
    && MemoryLayout<ProgressRecord>.offset(of: \.weight) == 4
    && MemoryLayout<ProgressRecord>.stride == 8
    && UInt(littleEndian: 0x01020304) == 0x01020304
}

public func process_progresses4(_ records: UnsafeBufferPointer<ProgressRecord>) -> ProgressResult {
    assert(validate_progresses4(records))
    var result = ProgressResult()
    records.withMemoryRebound(to: SIMD64<UInt64>.self) { recordsPtr in
        for i in recordsPtr.indices {
            let record = recordsPtr[i]
            let recordBits: SIMD64<UInt64> = (record & (0x00000000_000000FF as UInt64)) &>> UInt64(0)
            let progress = SIMD64<UInt8>(clamping: recordBits)
            let floatProgress = SIMD64<Float>(progress)
            let weightBits: SIMD64<UInt64> = (record & (0xFFFFFFFF_00000000 as UInt64)) &>> UInt64(32)
            let truncatedWeightBits: SIMD64<UInt32> = .init(clamping: weightBits)
            let weight = unsafeBitCast(truncatedWeightBits, to: SIMD64<Float>.self)
            result.raw_progress += floatProgress.sum()
            result.weighted_progress += (floatProgress * weight).sum()
        }
    }
    return result
}
