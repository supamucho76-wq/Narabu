import Foundation

/// 挑戦する行列ひとつぶん。
struct Stage: Identifiable, Equatable, Sendable {
    let id: Int
    /// 何の行列か。
    let name: String
    /// 並んでいる人数。
    let queueLength: Int
    /// 通り抜ける景色。前から順に等分して進む。
    let scenes: [SceneKind]
    /// 最後尾に着いたときの一言。
    let openingNote: String
    /// クリアしたときにもらえるもの。
    let reward: StageReward

    /// 進捗に対応する景色。
    func scene(atProgress progress: Int) -> SceneKind {
        scenes[sceneIndex(atProgress: progress)]
    }

    /// 今の景色に入ってからの進み具合。景色を繋ぐときの混ぜ具合に使う。
    func sceneBlend(atProgress progress: Int) -> Double {
        guard scenes.count > 1 else { return 1 }
        let span = sceneSpan
        let entered = max(0, progress) % span
        return min(1, Double(entered) / Double(max(1, span / 6)))
    }

    func previousScene(atProgress progress: Int) -> SceneKind? {
        let index = sceneIndex(atProgress: progress)
        return index > 0 ? scenes[index - 1] : nil
    }

    /// 景色ひとつぶんの人数。0除算にならないよう必ず1以上。
    private var sceneSpan: Int {
        max(1, queueLength / max(1, scenes.count))
    }

    /// 範囲外の進捗でも必ず有効な位置を返す。
    private func sceneIndex(atProgress progress: Int) -> Int {
        guard scenes.count > 1 else { return 0 }
        return min(scenes.count - 1, max(0, progress) / sceneSpan)
    }
}

/// クリア報酬。
struct StageReward: Equatable, Sendable {
    let coins: Int
    let gachaTickets: Int
    /// 初めてクリアしたときだけ手に入る装備。
    let equipmentID: String?
    /// 初めてクリアしたときだけ覚えるスキル。
    let skillID: String?
}

enum StageCatalog {
    static let stages: [Stage] = [
        Stage(
            id: 1, name: "コンビニ", queueLength: 10,
            scenes: [.residential],
            openingNote: "レジが1台しか開いていない。",
            reward: StageReward(coins: 50, gachaTickets: 1,
                                equipmentID: "sneakers", skillID: "talk")
        ),
        Stage(
            id: 2, name: "人気ラーメン店", queueLength: 30,
            scenes: [.shopping],
            openingNote: "券売機の前で誰かが悩んでいる。",
            reward: StageReward(coins: 120, gachaTickets: 1,
                                equipmentID: "ticket", skillID: nil)
        ),
        Stage(
            id: 3, name: "人気カフェ", queueLength: 80,
            scenes: [.forest],
            openingNote: "全員が同じ限定ドリンクを頼んでいる。",
            reward: StageReward(coins: 260, gachaTickets: 1,
                                equipmentID: "sunglasses", skillID: "luck")
        ),
        Stage(
            id: 4, name: "テーマパーク", queueLength: 150,
            scenes: [.park],
            openingNote: "待ち時間の看板が、さっきより伸びた。",
            reward: StageReward(coins: 480, gachaTickets: 2,
                                equipmentID: "bicycle", skillID: "pressure")
        ),
        Stage(
            id: 5, name: "ライブ会場", queueLength: 300,
            scenes: [.night],
            openingNote: "物販の列と入場の列が混ざっている。",
            reward: StageReward(coins: 800, gachaTickets: 2,
                                equipmentID: "vipPass", skillID: nil)
        ),
        Stage(
            id: 6, name: "コミケ", queueLength: 500,
            scenes: [.hall],
            openingNote: "始発で来た人が、まだ後ろにいる。",
            reward: StageReward(coins: 1_400, gachaTickets: 3,
                                equipmentID: "motorbike", skillID: "negotiate")
        ),
        Stage(
            id: 7, name: "世界一のラーメン店", queueLength: 1_000,
            scenes: [.sea, .snow, .desert, .space, .hell, .heaven, .ramen],
            openingNote: "列がどこまで続いているのか、誰も知らない。",
            reward: StageReward(coins: 3_000, gachaTickets: 5,
                                equipmentID: nil, skillID: nil)
        )
    ]

    /// 一周したあとは、同じ行列がもっと長くなって戻ってくる。
    ///
    /// 壊れた保存データで番号が範囲外でも落ちないよう、必ず有効な位置に丸める。
    static func stage(number: Int, lap: Int) -> Stage {
        let index = ((number - 1) % stages.count + stages.count) % stages.count
        let base = stages[index]
        guard lap > 1 else { return base }

        let growth = 1 + Double(lap - 1) * 0.5
        return Stage(
            id: base.id,
            name: base.name,
            queueLength: Int(Double(base.queueLength) * growth),
            scenes: base.scenes,
            openingNote: base.openingNote,
            reward: StageReward(
                coins: Int(Double(base.reward.coins) * growth),
                gachaTickets: base.reward.gachaTickets,
                equipmentID: nil,
                skillID: nil
            )
        )
    }

    static var count: Int { stages.count }
}
