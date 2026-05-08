import XCTest
@testable import Bagyt

final class HealthIndexCalculatorTests: XCTestCase {
    func testPerfectSnapshotScoresOneHundred() {
        let breakdown = HealthIndexCalculator.make(
            steps: 8000,
            heartRate: 72,
            sleepHours: 8,
            stepsGoal: 8000,
            sleepGoal: 8
        )

        XCTAssertEqual(breakdown.basePoints, 60)
        XCTAssertEqual(breakdown.stepsPoints, 20)
        XCTAssertEqual(breakdown.heartPoints, 10)
        XCTAssertEqual(breakdown.sleepPoints, 10)
        XCTAssertEqual(breakdown.score, 100)
        XCTAssertTrue(breakdown.hasHeartRateData)
        XCTAssertTrue(breakdown.hasSleepData)
    }

    func testHalfStepsAndHalfSleepReduceScorePredictably() {
        let breakdown = HealthIndexCalculator.make(
            steps: 4000,
            heartRate: 70,
            sleepHours: 4,
            stepsGoal: 8000,
            sleepGoal: 8
        )

        XCTAssertEqual(breakdown.stepsPoints, 10)
        XCTAssertEqual(breakdown.heartPoints, 10)
        XCTAssertEqual(breakdown.sleepPoints, 5)
        XCTAssertEqual(breakdown.score, 85)
    }

    func testNonOptimalHeartRateGetsPartialCredit() {
        let highPulse = HealthIndexCalculator.make(
            steps: 8000,
            heartRate: 112,
            sleepHours: 8,
            stepsGoal: 8000,
            sleepGoal: 8
        )

        XCTAssertEqual(highPulse.heartPoints, 5)
        XCTAssertEqual(highPulse.score, 95)
        XCTAssertTrue(highPulse.hasHeartRateData)
    }

    func testMissingHeartAndSleepDataUseSafeFallbacks() {
        let breakdown = HealthIndexCalculator.make(
            steps: 0,
            heartRate: 0,
            sleepHours: 0,
            stepsGoal: 0,
            sleepGoal: 0
        )

        XCTAssertEqual(breakdown.stepsGoal, 1)
        XCTAssertEqual(breakdown.sleepGoal, 0.1, accuracy: 0.001)
        XCTAssertEqual(breakdown.stepsPoints, 0)
        XCTAssertEqual(breakdown.heartPoints, 7)
        XCTAssertEqual(breakdown.sleepPoints, 7)
        XCTAssertEqual(breakdown.score, 74)
        XCTAssertFalse(breakdown.hasHeartRateData)
        XCTAssertFalse(breakdown.hasSleepData)
    }

    func testNegativeInputsAreClamped() {
        let breakdown = HealthIndexCalculator.make(
            steps: -500,
            heartRate: -20,
            sleepHours: -3,
            stepsGoal: 8000,
            sleepGoal: 8
        )

        XCTAssertEqual(breakdown.stepsPoints, 0)
        XCTAssertEqual(breakdown.heartPoints, 7)
        XCTAssertEqual(breakdown.sleepPoints, 7)
        XCTAssertEqual(breakdown.sleepHours, 0, accuracy: 0.001)
        XCTAssertFalse(breakdown.hasHeartRateData)
        XCTAssertFalse(breakdown.hasSleepData)
    }
}
