import SwiftUI

struct MistakeRoute: Hashable {}

enum MistakeSort: String, CaseIterable, Identifiable {
    case time
    case year
    case count

    var id: String { rawValue }

    var title: String {
        switch self {
        case .time: return "時間"
        case .year: return "年度"
        case .count: return "回数"
        }
    }
}

/// 一度でも間違えた問題の累積リスト。正解しても消えない。
struct MistakeHistoryView: View {
    @EnvironmentObject var store: QuestionStore
    @State private var sort: MistakeSort = .time
    @State private var expanded: Set<String> = []

    struct Entry {
        let q: STQuestion
        let wrong: Int
        let last: Date?
        let tries: Int
        let accuracy: Double
    }

    var entries: [Entry] {
        let map = Dictionary(uniqueKeysWithValues: QuestionsData.all.map { ($0.id, $0) })
        let yearOrder = Dictionary(uniqueKeysWithValues: QuestionsData.years.enumerated().map { ($1, $0) })
        var arr: [Entry] = []
        for (id, w) in store.wrongTotal {
            guard let q = map[id] else { continue }
            let t = store.attempts[id] ?? 0
            let c = store.correctCount[id] ?? 0
            arr.append(Entry(
                q: q,
                wrong: w,
                last: store.lastWrongAt[id],
                tries: t,
                accuracy: t > 0 ? Double(c) / Double(t) : 0
            ))
        }
        switch sort {
        case .time:
            arr.sort { ($0.last ?? .distantPast) > ($1.last ?? .distantPast) }
        case .year:
            arr.sort {
                let a = yearOrder[$0.q.year] ?? Int.max
                let b = yearOrder[$1.q.year] ?? Int.max
                if a != b { return a < b }
                return $0.q.number < $1.q.number
            }
        case .count:
            arr.sort {
                if $0.wrong != $1.wrong { return $0.wrong > $1.wrong }
                return ($0.last ?? .distantPast) > ($1.last ?? .distantPast)
            }
        }
        return arr
    }

    static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d H:mm"
        return f
    }()

    var body: some View {
        VStack {
            Picker("並び替え", selection: $sort) {
                ForEach(MistakeSort.allCases) { s in
                    Text(s.title).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            if entries.isEmpty {
                Spacer()
                Text("まだ間違い記録がありません")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    Section {
                        NavigationLink(value: QuizConfig(
                            title: "間違い履歴の復習",
                            questionIds: entries.map { $0.q.id }
                        )) {
                            Label("この並びでまとめて復習 (\(entries.count)問)", systemImage: "play.fill")
                        }
                    }
                    Section("一度でも間違えた問題 (\(entries.count)問・累計\(store.totalWrongAnswers)回)") {
                        ForEach(entries, id: \.q.id) { e in
                            VStack(alignment: .leading, spacing: 6) {
                                Button {
                                    if expanded.contains(e.q.id) {
                                        expanded.remove(e.q.id)
                                    } else {
                                        expanded.insert(e.q.id)
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("\(e.q.year) 問\(e.q.number)")
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Text("誤答\(e.wrong)回")
                                                .bold()
                                                .foregroundColor(.red)
                                        }
                                        HStack {
                                            Text(e.q.category)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("最終 \(e.last.map { Self.dateFmt.string(from: $0) } ?? "―")・正答率\(Int(e.accuracy * 100))%")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                if expanded.contains(e.q.id) {
                                    Text(e.q.question).font(.callout).bold()
                                        .fixedSize(horizontal: false, vertical: true)
                                    FigureView(questionId: e.q.id, caption: "参考図(タップで拡大)")
                                    HStack(alignment: .top, spacing: 4) {
                                        Text("正解:").font(.caption).foregroundColor(.secondary)
                                        Text("\(e.q.answerLabel) \(e.q.choices[e.q.answerIndex])").font(.caption).bold()
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                                    ExplanationBody(text: e.q.explanation, font: .callout)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("間違い履歴")
        .navigationBarTitleDisplayMode(.inline)
    }
}
