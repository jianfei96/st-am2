import Foundation

// 問題データ: IPA公開のITストラテジスト午前II過去問題 16回分(各25問・全400問)を
// 文字起こし・校正し、公式解答例と全問照合したもの。
// 解説・分野分類は本アプリのオリジナル。
// 出典: IPA 独立行政法人情報処理推進機構 公開過去問題
// (https://www.ipa.go.jp/shiken/mondai-kaiotu/index.html 利用条件に基づき利用可)
struct QuestionsData {
    static let all: [STQuestion] = load()

    private static func load() -> [STQuestion] {
        guard let url = Bundle.main.url(forResource: "questions", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        // 1件の不良レコードで全体が読めなくならないよう、
        // 要素ごとに復元を試みて成功分だけ採用する(問題追加時の互換性確保)。
        // 未知フィールドはCodableの既定動作で無視される。
        if let qs = try? JSONDecoder().decode([Lossy<STQuestion>].self, from: data) {
            let ok = qs.compactMap { $0.value }
            if !ok.isEmpty { return ok }
        }
        return (try? JSONDecoder().decode([STQuestion].self, from: data)) ?? []
    }

    static let years: [String] = [
        "令和7年度春期", "令和6年度春期", "令和5年度春期", "令和4年度春期",
        "令和3年度春期", "令和元年度秋期", "平成30年度秋期", "平成29年度秋期",
        "平成28年度秋期", "平成27年度秋期", "平成26年度秋期", "平成25年度秋期",
        "平成24年度秋期", "平成23年度秋期", "平成22年度秋期", "平成21年度秋期",
    ]
}
