import Foundation

struct STQuestion: Identifiable, Codable, Hashable {
    var id: String
    var year: String
    var number: Int
    var category: String
    var question: String
    var choices: [String]
    var answerIndex: Int
    var explanation: String

    var answerLabel: String {
        ["ア", "イ", "ウ", "エ"][answerIndex]
    }
}

/// 要素単位で復元を試みるラッパー。不良要素があっても全体の読込みを壊さない。
struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        value = try? c.decode(T.self)
    }
}

enum STCategory: String, CaseIterable {    case keieiSenryaku = "経営戦略"
    case systemSenryaku = "システム戦略"
    case systemKikaku = "システム企画・調達"
    case project = "プロジェクト・サービス"
    case kansa = "監査・内部統制・セキュリティ"
    case kaikei = "会計・法務・その他"

    static func category(for question: STQuestion) -> STCategory? {
        STCategory(rawValue: question.category)
    }
}
