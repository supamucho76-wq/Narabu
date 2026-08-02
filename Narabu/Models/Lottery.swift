import SwiftUI

/// ミッションに成功したあとに走る抽選。
///
/// 抜ける人数は腕で決まっているが、そこに**まだ分からない時間**を挟む。
/// 気持ちよさの正体は結果そのものではなく、決まるまでの数秒のほうにある。
///
/// **外れても損はしない。** 上乗せがつかないだけで、腕で稼いだぶんは必ずもらえる。
/// だから待たされること自体が罰にならず、何度でも回せる。
struct Lottery: Equatable, Sendable {
    enum Result: Int, CaseIterable, Equatable, Sendable {
        case miss
        case hit
        case big
        case jackpot

        /// 抜ける人数にかける上乗せ。
        var multiplier: Int {
            switch self {
            case .miss: 1
            case .hit: 2
            case .big: 3
            case .jackpot: 5
            }
        }

        /// 出る割合。合計で1.0。
        ///
        /// **当たらない抽選は、ただの待ち時間になる。**
        /// ほぼ半分は上乗せがつくようにして、回すこと自体を楽しくしている。
        var rate: Double {
            switch self {
            case .miss: 0.55
            case .hit: 0.27
            case .big: 0.13
            case .jackpot: 0.05
            }
        }

        var headline: String {
            switch self {
            case .miss: "ざんねん"
            case .hit: "そろった！"
            case .big: "大当たり！"
            case .jackpot: "超・大当たり！！"
            }
        }

        var color: Color {
            switch self {
            case .miss: Color(red: 0.62, green: 0.64, blue: 0.70)
            case .hit: Color(red: 1.00, green: 0.80, blue: 0.26)
            case .big: Color(red: 1.00, green: 0.42, blue: 0.24)
            case .jackpot: Color(red: 1.00, green: 0.26, blue: 0.56)
            }
        }

        /// 煽りの長さ。当たりが大きいほど長く引っぱる。
        var reachDuration: Double {
            switch self {
            case .miss: 1.1
            case .hit: 1.3
            case .big: 1.8
            case .jackpot: 2.4
            }
        }

        /// 煽りのあいだに鳴らすチャイムの回数。
        var chimeCount: Int {
            switch self {
            case .miss: 5
            case .hit: 6
            case .big: 8
            case .jackpot: 11
            }
        }
    }

    let result: Result
    /// 外れなのに煽ること。**これがないと、引っぱった時点で当たりが確定してしまう。**
    ///
    /// 煽られてから外れる回数のほうが多いからこそ、そろった瞬間に意味が出る。
    let teases: Bool

    /// 引っぱって見せるか。
    ///
    /// ×2 は数が多いので引っぱらない。毎回2秒待たされたら、当たりが煩わしくなる。
    /// **軽い当たりはさっと通し、重い当たりとガセだけを引っぱる。**
    var showsReach: Bool { result == .big || result == .jackpot || teases }

    /// 回した結果を決める。
    ///
    /// - Parameter seed: 同じ場面では同じ結果になるようにするための種。
    static func draw(seed: Int) -> Lottery {
        var roll = QueueEngine.unitRandom(seed, salt: 0xC0FE)
        var result = Result.miss

        for candidate in Result.allCases {
            if roll < candidate.rate {
                result = candidate
                break
            }
            roll -= candidate.rate
        }

        // 外れの4割は、当たったふりをして引っぱる。
        // 引っぱられた回の半分以上が外れになる割合にしてある。
        let teases = result == .miss && QueueEngine.unitRandom(seed, salt: 0xBEEF) < 0.40
        return Lottery(result: result, teases: teases)
    }
}
