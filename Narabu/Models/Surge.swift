import Foundation

/// 前へ進んだときの一連の演出。
///
/// アクションでもミッションでもアイテムでも、進んだら必ずこれを通す。
/// 数字だけ変わって終わると、何人抜いたのか体感できない。
struct Surge: Equatable {
    /// 抜いた人数によって、演出の強さを変える。
    enum Tier: Equatable {
        case slight
        case moderate
        case strong
        case massive

        static func of(_ people: Int) -> Tier {
            switch people {
            case ..<5: .slight
            case ..<15: .moderate
            case ..<30: .strong
            default: .massive
            }
        }

        /// 演出の長さ。長すぎるとテンポが死ぬので、大きくても2秒以内。
        var duration: Double {
            switch self {
            case .slight: 0.45
            case .moderate: 0.8
            case .strong: 1.25
            case .massive: 1.9
            }
        }

        /// カメラの寄りの強さ。
        var cameraPush: Double {
            switch self {
            case .slight: 0.35
            case .moderate: 0.7
            case .strong: 1.0
            case .massive: 1.0
            }
        }

        /// 速度線を出すか。
        var showsSpeedLines: Bool {
            switch self {
            case .slight, .moderate: false
            case .strong, .massive: true
            }
        }

        /// 画面を白く光らせるか。
        var flashes: Bool { self == .massive }

        /// 中央に出す人数表示の大きさ。
        var bannerSize: Double {
            switch self {
            case .slight: 40
            case .moderate: 54
            case .strong: 68
            case .massive: 86
            }
        }

        var headline: String? {
            switch self {
            case .slight, .moderate: nil
            case .strong: "ごぼう抜き！"
            case .massive: "大成功！"
            }
        }
    }

    /// 走り出したときの残り人数。
    let fromRemaining: Int
    /// 実際に抜いた人数。
    let peopleSkipped: Int
    let startedAt: Date
    /// アイテムを使ったときだけ、乗り物が付く。
    let vehicle: VehicleKind?
    /// 乗り物の名前。画面に出す。
    let vehicleName: String?

    var tier: Tier { Tier.of(peopleSkipped) }

    /// 乗り物に乗っているときは、演出を長めに取る。
    var duration: Double {
        vehicle == nil ? tier.duration : max(tier.duration, 1.6)
    }

    /// 0 から 1 まで。終わったら 1 のまま。
    func progress(at date: Date) -> Double {
        min(1, max(0, date.timeIntervalSince(startedAt) / duration))
    }

    func isFinished(at date: Date) -> Bool { progress(at: date) >= 1 }

    /// 走っている途中の見かけの残り人数。数字はここに合わせて減らす。
    func displayedRemaining(at date: Date) -> Int {
        fromRemaining - Int((Double(peopleSkipped) * eased(progress(at: date))).rounded())
    }

    /// いま何人抜いたか。
    func countedSoFar(at date: Date) -> Int {
        Int((Double(peopleSkipped) * eased(progress(at: date))).rounded())
    }

    /// カメラの寄り。ぐっと寄ってから戻る。
    func cameraStrength(at date: Date) -> Double {
        let t = progress(at: date)
        guard t < 1 else { return 0 }
        return sin(t * .pi) * tier.cameraPush
    }

    /// 走り出しと止まりぎわをなめらかにする。
    private func eased(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}
