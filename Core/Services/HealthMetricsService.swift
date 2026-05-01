import Foundation

/// Posts HealthKit snapshots to the Panacea Laravel API.
///
/// The on-device HealthKit data is read by `HealthKitManager`. This service
/// turns the latest values into a `POST /api/health/metrics` batch so the
/// React dashboard's Health Summary card can show real numbers.
///
/// Endpoint contract (matches the Laravel `HealthMetricController::store`):
///   POST /api/health/metrics
///   { "metrics": [
///       {"type": "steps",          "value": 5234, "unit": "count",   "recorded_at": "...", "source": "healthkit"},
///       {"type": "heart_rate",     "value": 72,   "unit": "bpm",     "recorded_at": "...", "source": "healthkit"},
///       {"type": "sleep_duration", "value": 420,  "unit": "minutes", "recorded_at": "...", "source": "healthkit"},
///   ]}
///   -> 201 { "inserted": 3 }
///
/// Each call creates fresh rows. We deliberately do NOT use Idempotency-Key
/// here so a steps-progressing-through-the-day still surfaces in the
/// summary. Backend authorization is via the existing Sanctum bearer token
/// in Keychain (set on login), reused through `APIClient`.
struct HealthMetricsBatchResponse: Decodable {
    let inserted: Int
}

final class HealthMetricsService {
    static let shared = HealthMetricsService()
    private init() {}

    /// ISO8601 with fractional seconds — matches what Laravel's date casting
    /// roundtrips cleanly.
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Uploads the current HealthKit snapshot.
    ///
    /// - Skips silently if there is no auth token in Keychain (user not
    ///   logged in) or if the token is the offline test token.
    /// - Skips silently if every metric is zero (HealthKit hasn't returned
    ///   data yet).
    func uploadSnapshot(
        steps: Int,
        heartRate: Int,
        sleepMinutes: Int,
        completion: ((Result<Int, APIError>) -> Void)? = nil
    ) {
        guard let token = KeychainHelper.read("auth_token"), !token.isEmpty else {
            print("⏭️ Health upload skipped: no auth token")
            return
        }
        if token.hasPrefix("offline-") {
            print("⏭️ Health upload skipped: offline auth")
            return
        }

        let recordedAt = HealthMetricsService.iso8601.string(from: Date())

        var metrics: [[String: Any]] = []
        if steps > 0 {
            metrics.append([
                "type": "steps",
                "value": steps,
                "unit": "count",
                "recorded_at": recordedAt,
                "source": "healthkit",
            ])
        }
        if heartRate > 0 {
            metrics.append([
                "type": "heart_rate",
                "value": heartRate,
                "unit": "bpm",
                "recorded_at": recordedAt,
                "source": "healthkit",
            ])
        }
        if sleepMinutes > 0 {
            metrics.append([
                "type": "sleep_duration",
                "value": sleepMinutes,
                "unit": "minutes",
                "recorded_at": recordedAt,
                "source": "healthkit",
            ])
        }

        guard !metrics.isEmpty else {
            print("⏭️ Health upload skipped: nothing to send (HealthKit values all zero)")
            return
        }

        print("🩺 Uploading \(metrics.count) HealthKit metric(s)…")

        APIClient.shared.request(
            "POST",
            path: "health/metrics",
            body: ["metrics": metrics]
        ) { (result: Result<HealthMetricsBatchResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ Health upload OK: \(response.inserted) row(s)")
                completion?(.success(response.inserted))
            case .failure(let error):
                print("❌ Health upload failed: \(error.localizedDescription)")
                completion?(.failure(error))
            }
        }
    }
}
