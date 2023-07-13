import XCTest
import CXXDotProduct
import DotProductRNG
import DotProduct


final class DotProductTests: XCTestCase {
    static let recordSize = 1024
    static let iterations = 1_000
    static let recordsPerIteration = 1_000
    static let tolerance: Float = 0.5
    struct TestData {
        var progresses: [UInt8]
        var weights: [Float]
        var records: [ProgressRecord]
        var answer: ProgressResult
        var floatProgresses: [Float]
    }
    static var testDatas: [TestData]!
    static var randomSeed: UInt64!
    var expectedResults: [ProgressResult] {
        Self.testDatas.map(\.answer)
    }
    
#if canImport(Darwin)
    override class var defaultMetrics: [XCTMetric] {
        super.defaultMetrics + [XCTCPUMetric(limitingToCurrentThread: true), XCTMemoryMetric()]
    }
    
    func doMeasure(_ block: () -> Void) {
        super.measure(metrics: Self.defaultMetrics, block: block)
    }
#else
    func doMeasure(_ block: () -> Void) {
        measure(block: block)
    }
#endif
    
    override class func setUp() {
        var isReleaseMode = true
        assert({
            isReleaseMode.toggle()
            return true
        }())
        print("Testing mode is", isReleaseMode ? "release" : "debug")
        
        let randomSeed: UInt64
        if let randomSeedString = ProcessInfo.processInfo.environment["DOT_PRODUCT_TEST_RANDOM_SEED"] {
            print("Reading random seed from environment... ", terminator: "")
            guard let envRandomSeed = UInt64(randomSeedString) else {
                print("failed")
                return XCTFail("failed to read random seed")
            }
            print("ok")
            randomSeed = envRandomSeed
        } else {
            randomSeed = UInt64.random(in: (.min)...(.max))
        }
        print("random seed is \(randomSeed)")
        var rng: some RandomNumberGenerator = DPRNG(seed: randomSeed)
        testDatas = (1...recordsPerIteration).map { _ in
            let records = (1...recordSize).map { _ in
                ProgressRecord(
                    progress: .random(in: (.min)...(.max), using: &rng),
                    weight: .random(in: (-10.0)...(10.0), using: &rng)
                )
            }
            let progresses = records.map(\.progress)
            let floatProgresses = progresses.map(Float.init)
            let weights = records.map(\.weight)
            let answer = {
                var result = ProgressResult()
                for (progress, weight) in zip(progresses, weights) {
                    result.raw_progress += Float(progress)
                    result.weighted_progress += Float(progress) * weight
                }
                return result
            }()
            return .init(progresses: progresses, weights: weights, records: records, answer: answer, floatProgresses: floatProgresses)
        }
    }
    
#if canImport(Darwin)
    override class var defaultMeasureOptions: XCTMeasureOptions {
        let result = XCTMeasureOptions()
        result.iterationCount = Self.iterations
        return result
    }
#endif
    
    private func assertResults(_ results: [ProgressResult], file: StaticString = #file, line: UInt = #line) {
        for (result, expected) in zip(results, expectedResults) {
            XCTAssertEqual(result.raw_progress, expected.raw_progress, accuracy: Self.tolerance)
            XCTAssertEqual(result.weighted_progress, expected.weighted_progress, accuracy: Self.tolerance)
        }

    }
    
    func testProgressStructOfArrays() throws {
        var results = Array(repeating: ProgressResult(), count: Self.testDatas.count)
        doMeasure { // NOTE: This block should be zero allocations
            for (i, testData) in Self.testDatas.enumerated() {
                var isContiguousAvailable = false
                testData.progresses.withContiguousStorageIfAvailable { progressesPtr in
                    testData.weights.withContiguousStorageIfAvailable { weightsPtr in
                        isContiguousAvailable = true
                        results[i] = aggregate_progress1(progressesPtr.baseAddress, weightsPtr.baseAddress, progressesPtr.count)
                    }
                }
                precondition(isContiguousAvailable)
            }
        }
        
        assertResults(results)
    }
    
    func testProgressStructOfFloatArrays() throws {
        var results = Array(repeating: ProgressResult(), count: Self.testDatas.count)
        doMeasure { // NOTE: This block should be zero allocations
            for (i, testData) in Self.testDatas.enumerated() {
                var isContiguousAvailable = false
                testData.floatProgresses.withContiguousStorageIfAvailable { progressesPtr in
                    testData.weights.withContiguousStorageIfAvailable { weightsPtr in
                        isContiguousAvailable = true
                        results[i] = aggregate_progress5(progressesPtr.baseAddress, weightsPtr.baseAddress, progressesPtr.count)
                    }
                }
                precondition(isContiguousAvailable)
            }
        }
        
        assertResults(results)
    }
    func testProgressArrayOfStructs() throws {
        var results = Array(repeating: ProgressResult(), count: Self.testDatas.count)
        let expectedResults = Self.testDatas.map(\.answer)
        doMeasure { // NOTE: This block should be zero allocations
            for (i, testData) in Self.testDatas.enumerated() {
                var isContiguousStorageAvailable = false
                testData.records.withContiguousStorageIfAvailable { recordsPtr in
                    isContiguousStorageAvailable = true
                    results[i] = aggregate_progress2(recordsPtr.baseAddress, recordsPtr.count)
                }
                precondition(isContiguousStorageAvailable)
            }
        }
        
        assertResults(results)
    }
    
    func testSwiftSIMDStructOfArrays() {
        var results = Array(repeating: ProgressResult(), count: Self.testDatas.count)
        doMeasure { // NOTE: This block should be zero allocations
            for i in Self.testDatas.indices {
                var isContiguousAvailable = false
                Self.testDatas[i].progresses.withContiguousStorageIfAvailable { progressesPtr in
                    Self.testDatas[i].weights.withContiguousStorageIfAvailable { weightsPtr in
                        isContiguousAvailable = true
                        results[i] = process_progresses3(progressesPtr, weightsPtr)
                    }
                }
                precondition(isContiguousAvailable)
            }
        }
        
        assertResults(results)
    }
    
    func testSwiftSIMDArrayOfStructs() {
        var results = Array(repeating: ProgressResult(), count: Self.testDatas.count)
        doMeasure { // NOTE: this block should be zero allocations
            for i in Self.testDatas.indices {
                var isContiguousAvailable = false
                Self.testDatas[i].records.withContiguousStorageIfAvailable { recordsPtr in
                    isContiguousAvailable = true
                    results[i] = process_progresses4(recordsPtr)
                }
                precondition(isContiguousAvailable)
            }
        }
        
        assertResults(results)
    }
    
    func testSIMDArrayOfStructsBasic() {
        let records = (1...64).map { i in
            ProgressRecord(progress: UInt8(i), weight: 1.0)
        }
        
        var results = records.map { _ in ProgressResult() }
        let expectedTotal = records.map(\.progress).map(Float.init).reduce(0.0, +)
        
        let result = records.withUnsafeBufferPointer {
            process_progresses4($0)
        }
        XCTAssertEqual(result.raw_progress, expectedTotal)
    }
}
