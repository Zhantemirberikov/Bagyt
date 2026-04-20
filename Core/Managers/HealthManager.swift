import HealthKit

final class HealthManager {
    static let shared = HealthManager()
    private let healthStore = HKHealthStore()

    private init() {}

    // MARK: - TYPES
    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMassIndex)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKQuantityType.quantityType(forIdentifier: .vo2Max)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
    }

    // MARK: - REQUEST ACCESS
    func requestAccess(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }

        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            if let error = error {
                print("❌ HealthKit error:", error.localizedDescription)
            }
            completion(success)
        }
    }

    // MARK: - GENERIC DAILY SUM
    private func fetchTodaySum(
        type: HKQuantityTypeIdentifier,
        unit: HKUnit,
        completion: @escaping (Double) -> Void
    ) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: type) else {
            completion(0)
            return
        }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        let query = HKStatisticsQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in

            let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0

            DispatchQueue.main.async {
                completion(value)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - STEPS
    func fetchSteps(completion: @escaping (Double) -> Void) {
        fetchTodaySum(type: .stepCount, unit: .count(), completion: completion)
    }

    // MARK: - CALORIES
    func fetchCalories(completion: @escaping (Double) -> Void) {
        fetchTodaySum(type: .activeEnergyBurned, unit: .kilocalorie(), completion: completion)
    }

    // MARK: - DISTANCE (км)
    func fetchDistance(completion: @escaping (Double) -> Void) {
        fetchTodaySum(type: .distanceWalkingRunning, unit: .meterUnit(with: .kilo), completion: completion)
    }

    // MARK: - LAST VALUE (универсальный)
    private func fetchLatestSample(
        type: HKQuantityTypeIdentifier,
        unit: HKUnit,
        completion: @escaping (Double) -> Void
    ) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: type) else {
            completion(0)
            return
        }

        let query = HKSampleQuery(
            sampleType: quantityType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [
                NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            ]
        ) { _, samples, _ in

            let sample = samples?.first as? HKQuantitySample
            let value = sample?.quantity.doubleValue(for: unit) ?? 0

            DispatchQueue.main.async {
                completion(value)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - HEART RATE
    func fetchHeartRate(completion: @escaping (Double) -> Void) {
        fetchLatestSample(type: .heartRate, unit: HKUnit(from: "count/min"), completion: completion)
    }

    // MARK: - RESTING HEART RATE
    func fetchRestingHeartRate(completion: @escaping (Double) -> Void) {
        fetchLatestSample(type: .restingHeartRate, unit: HKUnit(from: "count/min"), completion: completion)
    }

    // MARK: - VO2 MAX
    func fetchVO2Max(completion: @escaping (Double) -> Void) {
        fetchLatestSample(type: .vo2Max, unit: HKUnit(from: "ml/kg*min"), completion: completion)
    }

    // MARK: - BLOOD OXYGEN
    func fetchOxygen(completion: @escaping (Double) -> Void) {
        fetchLatestSample(type: .oxygenSaturation, unit: .percent(), completion: completion)
    }

    // MARK: - WEIGHT
    func fetchWeight(completion: @escaping (Double) -> Void) {
        fetchLatestSample(type: .bodyMass, unit: .gramUnit(with: .kilo), completion: completion)
    }

    // MARK: - BMI
    func fetchBMI(completion: @escaping (Double) -> Void) {
        fetchLatestSample(type: .bodyMassIndex, unit: HKUnit.count(), completion: completion)
    }

    // MARK: - SLEEP (часы)
    func fetchSleep(completion: @escaping (Double) -> Void) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(0)
            return
        }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, _ in

            let total = samples?.reduce(0.0) { result, sample in
                guard let sample = sample as? HKCategorySample else { return result }
                return result + sample.endDate.timeIntervalSince(sample.startDate)
            } ?? 0

            let hours = total / 3600

            DispatchQueue.main.async {
                completion(hours)
            }
        }

        healthStore.execute(query)
    }
}
