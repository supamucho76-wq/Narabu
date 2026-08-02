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
    /// たどり着いたときの見出し。
    let arrivalHeadline: String
    /// たどり着いた瞬間の情景。何のために並んでいたのかが、ここで回収される。
    let arrivalStory: String
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
            arrivalHeadline: "コンビニに着いた",
            arrivalStory: "自動ドアが開いて、冷房と揚げ物の匂いが流れてきた。\nレジの店員と目が合う。ようやく自分の番だ。",
            reward: StageReward(coins: 50, gachaTickets: 1,
                                equipmentID: "sneakers", skillID: "talk")
        ),
        Stage(
            id: 2, name: "人気ラーメン店", queueLength: 30,
            scenes: [.shopping],
            openingNote: "券売機の前で誰かが悩んでいる。",
            arrivalHeadline: "券売機の前に立った",
            arrivalStory: "湯気とスープの匂いが顔にあたる。\n背中越しに「次の方どうぞ」と声がかかった。",
            reward: StageReward(coins: 120, gachaTickets: 1,
                                equipmentID: "ticket", skillID: nil)
        ),
        Stage(
            id: 3, name: "人気カフェ", queueLength: 80,
            scenes: [.forest],
            openingNote: "全員が同じ限定ドリンクを頼んでいる。",
            arrivalHeadline: "カフェのカウンターに着いた",
            arrivalStory: "全員が頼んでいた限定ドリンクを、ようやく自分も頼めた。\n名前を書かれたカップが差し出される。",
            reward: StageReward(coins: 260, gachaTickets: 1,
                                equipmentID: "sunglasses", skillID: "luck")
        ),
        Stage(
            id: 4, name: "テーマパーク", queueLength: 150,
            scenes: [.park],
            openingNote: "待ち時間の看板が、さっきより伸びた。",
            arrivalHeadline: "ゲートをくぐった",
            arrivalStory: "音楽が大きくなり、目の前に城が現れた。\n並んでいた150分が、ここから始まる一日のための時間だったと分かる。",
            reward: StageReward(coins: 480, gachaTickets: 2,
                                equipmentID: "bicycle", skillID: "pressure")
        ),
        Stage(
            id: 5, name: "ライブ会場", queueLength: 300,
            scenes: [.night],
            openingNote: "物販の列と入場の列が混ざっている。",
            arrivalHeadline: "会場に入った",
            arrivalStory: "扉が開いた瞬間、低音が体を打った。\n外で待っていた寒さを、もう誰も覚えていない。",
            reward: StageReward(coins: 800, gachaTickets: 2,
                                equipmentID: "vipPass", skillID: nil)
        ),
        Stage(
            id: 6, name: "コミケ", queueLength: 500,
            scenes: [.hall],
            openingNote: "始発で来た人が、まだ後ろにいる。",
            arrivalHeadline: "目当ての島にたどり着いた",
            arrivalStory: "最後の1冊が、ちょうど目の前に残っていた。\n始発で来た甲斐があったと、心から思う。",
            reward: StageReward(coins: 1_400, gachaTickets: 3,
                                equipmentID: "motorbike", skillID: "negotiate")
        ),
        Stage(
            id: 7, name: "世界一のラーメン店", queueLength: 1_000,
            scenes: [.sea, .snow, .desert, .space, .hell, .heaven, .ramen],
            openingNote: "列がどこまで続いているのか、誰も知らない。",
            arrivalHeadline: "ついに、暖簾をくぐった",
            arrivalStory: "海を渡り、砂漠を抜け、宇宙を通り、地獄と天国を経て、\nようやく丼が置かれた。ごく普通の、うまいラーメンだった。",
            reward: StageReward(coins: 3_000, gachaTickets: 5,
                                equipmentID: nil, skillID: nil)
        ),

        // ここから先は、並んでいる先がだんだんおかしくなっていく。
        //
        // 序盤を現実にありそうな行列で固めているのは、この落差のため。
        // **並んでいる先が非常識なほど、同じことをしている自分が可笑しく見える。**
        Stage(
            id: 8, name: "限定スニーカー発売日", queueLength: 1_500,
            scenes: [.night, .shopping],
            openingNote: "3日前から並んでいる人がいるらしい。",
            arrivalHeadline: "シャッターが上がった",
            arrivalStory: "3日ぶんの寝袋を畳んで、店内に入る。\n棚には、自分のサイズだけが残っていた。",
            reward: StageReward(coins: 4_200, gachaTickets: 5,
                                equipmentID: nil, skillID: nil)
        ),
        Stage(
            id: 9, name: "空港の保安検査", queueLength: 2_000,
            scenes: [.hall],
            openingNote: "搭乗まであと20分。列は動いていない。",
            arrivalHeadline: "ベルトを外した",
            arrivalStory: "ノートパソコンをトレーに置き、靴を脱ぐ。\nゲートを抜けた瞬間、搭乗案内が最終呼び出しに変わった。",
            reward: StageReward(coins: 5_800, gachaTickets: 5,
                                equipmentID: nil, skillID: nil)
        ),
        Stage(
            id: 10, name: "富士山頂のトイレ", queueLength: 3_000,
            scenes: [.snow],
            openingNote: "標高3776メートル。全員が同じ用事で並んでいる。",
            arrivalHeadline: "扉が開いた",
            arrivalStory: "日の出よりも、こちらのほうが待ち遠しかった。\n協力金は200円。人生でいちばん安いと思った。",
            reward: StageReward(coins: 8_000, gachaTickets: 6,
                                equipmentID: nil, skillID: nil)
        ),
        Stage(
            id: 11, name: "宇宙船の搭乗口", queueLength: 4_500,
            scenes: [.space],
            openingNote: "地球を出る便は、今日この1便だけらしい。",
            arrivalHeadline: "タラップを踏んだ",
            arrivalStory: "窓の外に、さっきまで並んでいた地球が丸ごと見える。\n座席は通路側だった。",
            reward: StageReward(coins: 12_000, gachaTickets: 7,
                                equipmentID: nil, skillID: nil)
        ),
        Stage(
            id: 12, name: "天国の入場審査", queueLength: 7_000,
            scenes: [.heaven],
            openingNote: "前の人が、生前のことを聞かれている。",
            arrivalHeadline: "門の前に立った",
            arrivalStory: "名簿をめくる音だけが響いている。\n「少々お待ちください」と言われた。並ぶのは、ここでも同じらしい。",
            reward: StageReward(coins: 18_000, gachaTickets: 8,
                                equipmentID: nil, skillID: nil)
        ),
        Stage(
            id: 13, name: "転生待ちの列", queueLength: 10_000,
            scenes: [.hell, .heaven],
            openingNote: "次に何になるかは、窓口で決まるそうだ。",
            arrivalHeadline: "窓口に呼ばれた",
            arrivalStory: "希望を聞かれたので、行列のない人生と答えた。\n担当者は少し困った顔をして、番号札をもう1枚くれた。",
            reward: StageReward(coins: 26_000, gachaTickets: 9,
                                equipmentID: nil, skillID: nil)
        ),
        Stage(
            id: 14, name: "「ならぶ」を買うための列", queueLength: 15_000,
            scenes: [.residential, .shopping, .hall],
            openingNote: "行列に並ぶゲームを買うために、行列に並んでいる。",
            arrivalHeadline: "レジにたどり着いた",
            arrivalStory: "ようやく手に入れた。家に帰って起動すると、\n画面の中の自分が、また最後尾に立っていた。",
            reward: StageReward(coins: 40_000, gachaTickets: 12,
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
            arrivalHeadline: base.arrivalHeadline,
            arrivalStory: base.arrivalStory,
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
