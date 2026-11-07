import SwiftUI
import UIKit

struct QuizView: View {
    @EnvironmentObject var store: QuestionStore
    @Environment(\.dismiss) var dismiss
    let config: QuizConfig

    @State private var index = 0
    @State private var selected: Int? = nil
    @State private var showExplanation = false
    @State private var finished = false
    @State private var picks: [Int] = []
    @State private var results: [Bool] = []

    var questions: [STQuestion] {
        let map = Dictionary(uniqueKeysWithValues: QuestionsData.all.map { ($0.id, $0) })
        return config.questionIds.compactMap { map[$0] }
    }

    var correctCount: Int { results.filter { $0 }.count }
    /// 「わからない」の内部インデックス(公式の4択とは別枠)
    static let unknownIndex = 4

    var body: some View {
        VStack(spacing: 0) {
            if finished {
                ResultView(questions: questions, picks: picks, results: results, title: config.title) {
                    dismiss()
                }
            } else if index < questions.count {
                ProgressView(value: Double(index) / Double(questions.count))
                    .padding(.horizontal)
                    .padding(.top, 4)
                let q = questions[index]
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("問\(index + 1) / \(questions.count)")
                                    .font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text("\(q.year) 問\(q.number)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Text(q.category)
                                .font(.caption).bold()
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.blue.opacity(0.12))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                            Text(q.question)
                                .font(.body).bold()
                                .fixedSize(horizontal: false, vertical: true)
                            FigureView(questionId: q.id, caption: "参考図(タップで拡大)")

                            ForEach(0..<q.choices.count, id: \.self) { i in
                                Button {
                                    answer(i, q)
                                } label: {
                                    HStack(alignment: .top) {
                                        Text(["ア", "イ", "ウ", "エ"][i])
                                            .font(.headline)
                                            .frame(width: 28, height: 28)
                                            .background(choiceColor(i, q).opacity(0.15))
                                            .cornerRadius(6)
                                        Text(q.choices[i])
                                            .multilineTextAlignment(.leading)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if showExplanation {
                                            if i == q.answerIndex {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            } else if i == selected {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(choiceColor(i, q).opacity(selected == nil ? 0.05 : 0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(choiceColor(i, q), lineWidth: selected == i || (showExplanation && i == q.answerIndex) ? 2 : 1)
                                    )
                                    .cornerRadius(10)
                                }
                                .disabled(selected != nil)
                            }

                            // 「わからない」:当てずっぽう防止用。正解に計上せず解説を表示する
                            Button {
                                answer(Self.unknownIndex, q)
                            } label: {
                                HStack {
                                    Image(systemName: "questionmark.circle")
                                    Text("わからない(解説を見る)")
                                    Spacer()
                                    if selected == Self.unknownIndex {
                                        Image(systemName: "eye.fill")
                                            .foregroundColor(.orange)
                                    }
                                }
                                .padding()
                                .background(Color.orange.opacity(selected == Self.unknownIndex ? 0.15 : 0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.orange, lineWidth: selected == Self.unknownIndex ? 2 : 1)
                                        .opacity(selected == nil || selected == Self.unknownIndex ? 1 : 0.4)
                                )
                                .cornerRadius(10)
                            }
                            .disabled(selected != nil)

                            if showExplanation {
                                ExplanationCard(
                                    correct: selected == q.answerIndex,
                                    gaveUp: selected == Self.unknownIndex,
                                    answerLabel: q.answerLabel,
                                    explanation: q.explanation,
                                    meta: "\(q.year) 問\(q.number)・\(q.category)"
                                )
                                .id("expl")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: showExplanation) { v in
                        if v {
                            withAnimation { proxy.scrollTo("expl", anchor: .top) }
                        }
                    }
                }
                HStack {
                    Button("中断して戻る", role: .cancel) {
                        store.setResume(index, for: config.resumeKey)
                        dismiss()
                    }
                    Spacer()
                    Button(index + 1 == questions.count ? "結果を見る" : "次の問題へ") {
                        if index + 1 == questions.count {
                            store.clearResume(config.resumeKey)
                            finished = true
                        } else {
                            index += 1
                            store.setResume(index, for: config.resumeKey)
                            selected = nil
                            showExplanation = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selected == nil)
                }
                .padding()
            } else {
                Text("問題がありません")
            }
        }
        .navigationTitle(config.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if config.startIndex > 0 && config.startIndex < questions.count {
                index = config.startIndex
            }
        }
    }

    private func answer(_ i: Int, _ q: STQuestion) {
        guard selected == nil else { return }
        selected = i
        // 「わからない」は常に不正解扱い(正解数に加算しない・苦手として記録)
        let ok = (i == q.answerIndex)
        picks.append(i)
        results.append(ok)
        store.record(questionId: q.id, correct: ok)
        UINotificationFeedbackGenerator().notificationOccurred(
            ok ? .success : (i == Self.unknownIndex ? .warning : .error)
        )
        withAnimation { showExplanation = true }
    }

    func choiceColor(_ i: Int, _ q: STQuestion) -> Color {
        guard showExplanation else { return .gray }
        if i == q.answerIndex { return .green }
        if i == selected { return .red }
        return .gray
    }
}

/// 解説文を選択肢ブロックごとに分けて表示し、ブロック間に広い間隔を取る。
/// 改行で区切られた各ブロックが1つの選択肢の解説に対応する。
struct ExplanationBody: View {
    let text: String
    var font: Font = .body

    var blocks: [String] {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        if blocks.count <= 1 {
            Text(text)
                .font(font)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(blocks.indices, id: \.self) { i in
                    Text(blocks[i])
                        .font(font)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// 問題に参考図がバンドルされている場合に表示する(タップで拡大)。
struct FigureView: View {
    let questionId: String
    let caption: String
    @State private var showZoom = false

    var image: UIImage? {
        guard let url = Bundle.main.url(forResource: questionId, withExtension: "png", subdirectory: "Figures") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    var body: some View {
        if let img = image {
            VStack(alignment: .leading, spacing: 4) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
                    .onTapGesture { showZoom = true }
                Text(caption)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .sheet(isPresented: $showZoom) {
                NavigationView {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .navigationTitle("参考図")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { showZoom = false }
                        }
                    }
                }
            }
        }
    }
}

struct ExplanationCard: View {
    let correct: Bool
    let gaveUp: Bool
    let answerLabel: String
    let explanation: String
    let meta: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: correct ? "checkmark.circle.fill" : (gaveUp ? "eye.fill" : "xmark.circle.fill"))
                Text(correct ? "正解!" : (gaveUp ? "確認 — 正解は\(answerLabel)" : "不正解 — 正解は\(answerLabel)"))
                    .font(.headline)
                Spacer()
            }
            .foregroundColor(correct ? .green : (gaveUp ? .orange : .red))
            Divider()
            Label("解説", systemImage: "book.fill")
                .font(.subheadline).bold()
                .foregroundColor(.primary)
            ExplanationBody(text: explanation)
            Divider()
            Text(meta)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background((correct ? Color.green : (gaveUp ? Color.orange : Color.red)).opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke((correct ? Color.green : (gaveUp ? Color.orange : Color.red)).opacity(0.5), lineWidth: 1.5)
        )
        .cornerRadius(12)
    }
}

struct ResultView: View {
    let questions: [STQuestion]
    let picks: [Int]
    let results: [Bool]
    let title: String
    let onClose: () -> Void
    @State private var expanded: Set<String> = []

    var correct: Int { results.filter { $0 }.count }
    var total: Int { questions.count }
    var gaveUpCount: Int { picks.filter { $0 == QuizView.unknownIndex }.count }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text(title).font(.subheadline).foregroundColor(.secondary)
                    Text("\(correct) / \(total)問正解").font(.largeTitle).bold()
                    Text(String(format: "正答率 %.0f%%", total > 0 ? Double(correct) / Double(total) * 100 : 0))
                        .font(.title3)
                    if gaveUpCount > 0 {
                        Text("わからない: \(gaveUpCount)問(不正解に計上)")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                    Text(judgment).font(.footnote).foregroundColor(.secondary).multilineTextAlignment(.center)
                    Button("ホームに戻る") { onClose() }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            Section("解説を見直す (タップで展開)") {
                ForEach(Array(questions.enumerated()), id: \.element.id) { idx, q in
                    let ok = idx < results.count ? results[idx] : false
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            if expanded.contains(q.id) {
                                expanded.remove(q.id)
                            } else {
                                expanded.insert(q.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(ok ? .green : .red)
                                Text("\(q.year) 問\(q.number)")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: expanded.contains(q.id) ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary).font(.caption)
                            }
                        }
                        if expanded.contains(q.id) {
                            Text(q.question).font(.callout).bold()
                                .fixedSize(horizontal: false, vertical: true)
                            FigureView(questionId: q.id, caption: "参考図(タップで拡大)")
                            if idx < picks.count {
                                HStack(alignment: .top, spacing: 4) {
                                    Text("あなた:").font(.caption).foregroundColor(.secondary)
                                    if picks[idx] == QuizView.unknownIndex {
                                        Text("わからない")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("\(label(picks[idx])) \(q.choices[picks[idx]])")
                                            .font(.caption)
                                            .foregroundColor(ok ? .green : .red)
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            HStack(alignment: .top, spacing: 4) {
                                Text("正解:").font(.caption).foregroundColor(.secondary)
                                Text("\(q.answerLabel) \(q.choices[q.answerIndex])").font(.caption).bold()
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            ExplanationBody(text: q.explanation, font: .callout)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("結果")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func label(_ i: Int) -> String {
        guard (0..<4).contains(i) else { return "？" }
        return ["ア", "イ", "ウ", "エ"][i]
    }

    var judgment: String {
        let r = total > 0 ? Double(correct) / Double(total) : 0
        if r >= 0.8 { return "優秀です!この調子で苦手分野を潰しましょう。" }
        if r >= 0.6 { return "合格ラインです。間違えた問題の解説を復習しましょう。" }
        return "まずは分野別で基礎を固め、苦手問題を繰り返しましょう。"
    }
}
