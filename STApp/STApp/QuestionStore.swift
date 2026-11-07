import Foundation
import Combine

final class QuestionStore: ObservableObject {
    @Published var answers: [String: Bool] = [:] // questionId -> last correct?
    @Published var attempts: [String: Int] = [:]
    @Published var correctCount: [String: Int] = [:]
    /// 累積誤答記録(一度でも間違えた問題は消えない)
    @Published var wrongTotal: [String: Int] = [:] // questionId -> 累積誤答回数
    @Published var lastWrongAt: [String: Date] = [:] // questionId -> 最終誤答日時
    /// 年度別・分野別の再開位置(次に解く問題のindex)。端末内の途中状態のため
    /// バックアップ対象外とする。
    @Published var resume: [String: Int] = [:] // resumeKey -> index

    private let answersKey = "st_am2_answers_v1"
    private let attemptsKey = "st_am2_attempts_v1"
    private let correctKey = "st_am2_correct_v1"
    private let wrongTotalKey = "st_am2_wrongtotal_v1"
    private let lastWrongKey = "st_am2_lastwrong_v1"
    private let resumeKey = "st_am2_resume_v1"

    init() {
        load()
    }

    func record(questionId: String, correct: Bool) {
        answers[questionId] = correct
        attempts[questionId] = (attempts[questionId] ?? 0) + 1
        if correct {
            correctCount[questionId] = (correctCount[questionId] ?? 0) + 1
        } else {
            wrongTotal[questionId] = (wrongTotal[questionId] ?? 0) + 1
            lastWrongAt[questionId] = Date()
        }
        save()
    }

    func reset() {
        answers = [:]
        attempts = [:]
        correctCount = [:]
        wrongTotal = [:]
        lastWrongAt = [:]
        resume = [:]
        save()
    }

    // MARK: - 再開位置
    func resumeIndex(for key: String?) -> Int {
        guard let key else { return 0 }
        return resume[key] ?? 0
    }

    func setResume(_ index: Int, for key: String?) {
        guard let key else { return }
        resume[key] = index
        save()
    }

    func clearResume(_ key: String?) {
        guard let key else { return }
        resume.removeValue(forKey: key)
        save()
    }

    /// 一度でも間違えた問題(累積・消えない)のID一覧
    var everWrongIds: [String] {
        Array(wrongTotal.keys)
    }

    var totalWrongAnswers: Int {
        wrongTotal.values.reduce(0, +)
    }

    func isWrong(_ q: STQuestion) -> Bool {
        answers[q.id] == false
    }

    var totalAnswered: Int { answers.count }
    var totalCorrect: Int { answers.values.filter { $0 }.count }
    var accuracy: Double {
        guard !answers.isEmpty else { return 0 }
        return Double(totalCorrect) / Double(answers.count)
    }

    func accuracy(for questions: [STQuestion]) -> Double {
        let ids = Set(questions.map { $0.id })
        let rel = answers.filter { ids.contains($0.key) }
        guard !rel.isEmpty else { return 0 }
        return Double(rel.values.filter { $0 }.count) / Double(rel.count)
    }

    private func load() {
        if let d = UserDefaults.standard.dictionary(forKey: answersKey) as? [String: Bool] {
            answers = d
        }
        if let d = UserDefaults.standard.dictionary(forKey: attemptsKey) as? [String: Int] {
            attempts = d
        }
        if let d = UserDefaults.standard.dictionary(forKey: correctKey) as? [String: Int] {
            correctCount = d
        }
        if let d = UserDefaults.standard.dictionary(forKey: wrongTotalKey) as? [String: Int] {
            wrongTotal = d
        }
        if let d = UserDefaults.standard.dictionary(forKey: lastWrongKey) as? [String: Date] {
            lastWrongAt = d
        }
        if let d = UserDefaults.standard.dictionary(forKey: resumeKey) as? [String: Int] {
            resume = d
        }
        // 移行措置: 本更新前の「直近不正解」を初回の累積1回として引継ぐ
        for (id, v) in answers where v == false && wrongTotal[id] == nil {
            wrongTotal[id] = 1
        }
    }

    private func save() {
        UserDefaults.standard.set(answers, forKey: answersKey)
        UserDefaults.standard.set(attempts, forKey: attemptsKey)
        UserDefaults.standard.set(correctCount, forKey: correctKey)
        UserDefaults.standard.set(wrongTotal, forKey: wrongTotalKey)
        UserDefaults.standard.set(lastWrongAt, forKey: lastWrongKey)
        UserDefaults.standard.set(resume, forKey: resumeKey)
    }

    // MARK: - バックアップ (エクスポート / インポート)
    // 形式は版番号付きJSON。未知の版・未知フィールドは無視して
    // 既知部分だけを取り込むため、将来の形式変更とも互換性がある。
    // 履歴は問題ID基準で保持するため、問題追加時も既存履歴は維持される。
    // 未知の問題IDも破棄せず保持する(将来追加される問題に適用される)。
    func makeBackup() -> HistoryBackup {
        HistoryBackup(
            format: HistoryBackup.formatID,
            version: HistoryBackup.currentVersion,
            exportedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            data: HistoryPayload(
                answers: answers,
                attempts: attempts,
                correct: correctCount,
                wrongTotal: wrongTotal,
                wrongAt: lastWrongAt.mapValues { $0.timeIntervalSince1970 }
            )
        )
    }

    func exportJSON() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(makeBackup())
    }

    static func parseBackup(from data: Data) throws -> HistoryBackup {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        // 現行形式
        if let b = try? dec.decode(HistoryBackup.self, from: data) {
            guard b.format == HistoryBackup.formatID else {
                throw HistoryImportError.badFormat
            }
            // versionが未来のものでも既知フィールドは取り込む(前方互換)
            return b
        }
        // 旧形式(ペイロード直置き)の救済
        if let p = try? dec.decode(HistoryPayload.self, from: data) {
            return HistoryBackup(
                format: HistoryBackup.formatID,
                version: 0,
                exportedAt: Date(),
                appVersion: nil,
                data: p
            )
        }
        throw HistoryImportError.unreadable
    }

    /// 置換: 現在の履歴を捨てて取込分で上書き(機種変更時の復元用)
    func importReplace(_ backup: HistoryBackup) {
        answers = backup.data.answers
        attempts = backup.data.attempts
        correctCount = backup.data.correct
        wrongTotal = backup.data.wrongTotal
        lastWrongAt = backup.data.wrongAt.mapValues { Date(timeIntervalSince1970: $0) }
        save()
    }

    /// 結合: 回数は加算し、問題ごとの正誤は現在の端末の記録を優先(なければ取込分)。
    /// 誤答回数も加算、最終誤答日時は新しい方を採用。未知の問題IDもそのまま保持する。
    func importMerge(_ backup: HistoryBackup) {
        for (k, v) in backup.data.attempts {
            attempts[k] = (attempts[k] ?? 0) + v
        }
        for (k, v) in backup.data.correct {
            correctCount[k] = (correctCount[k] ?? 0) + v
        }
        for (k, v) in backup.data.answers where answers[k] == nil {
            answers[k] = v
        }
        for (k, v) in backup.data.wrongTotal {
            wrongTotal[k] = (wrongTotal[k] ?? 0) + v
        }
        for (k, v) in backup.data.wrongAt {
            let d = Date(timeIntervalSince1970: v)
            if let cur = lastWrongAt[k] {
                lastWrongAt[k] = max(cur, d)
            } else {
                lastWrongAt[k] = d
            }
        }
        save()
    }
}

struct HistoryPayload: Codable {
    var answers: [String: Bool] = [:]
    var attempts: [String: Int] = [:]
    var correct: [String: Int] = [:]
    // v2追加。旧ファイルには存在しないため復元時は空として扱う(後方互換)。
    var wrongTotal: [String: Int] = [:]
    var wrongAt: [String: TimeInterval] = [:]

    enum CodingKeys: String, CodingKey {
        case answers, attempts, correct, wrongTotal, wrongAt
    }

    init(answers: [String: Bool] = [:], attempts: [String: Int] = [:], correct: [String: Int] = [:], wrongTotal: [String: Int] = [:], wrongAt: [String: TimeInterval] = [:]) {
        self.answers = answers
        self.attempts = attempts
        self.correct = correct
        self.wrongTotal = wrongTotal
        self.wrongAt = wrongAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        answers = try c.decodeIfPresent([String: Bool].self, forKey: .answers) ?? [:]
        attempts = try c.decodeIfPresent([String: Int].self, forKey: .attempts) ?? [:]
        correct = try c.decodeIfPresent([String: Int].self, forKey: .correct) ?? [:]
        wrongTotal = try c.decodeIfPresent([String: Int].self, forKey: .wrongTotal) ?? [:]
        wrongAt = try c.decodeIfPresent([String: TimeInterval].self, forKey: .wrongAt) ?? [:]
    }
}

struct HistoryBackup: Codable {
    var format: String
    var version: Int
    var exportedAt: Date
    var appVersion: String?
    var data: HistoryPayload

    static let formatID = "st-am2-history"
    static let currentVersion = 2

    var answeredCount: Int { data.answers.count }
    var everWrongCount: Int { data.wrongTotal.count }
}

enum HistoryImportError: LocalizedError {
    case unreadable
    case badFormat

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "ファイルを読めませんでした。正しいバックアップJSONを選択してください。"
        case .badFormat:
            return "このアプリのバックアップ形式ではありません。"
        }
    }
}
