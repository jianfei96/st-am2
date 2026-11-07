import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: QuestionStore
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: QuizConfig.self) { config in
                    QuizView(config: config)
                }
                .navigationDestination(for: MistakeRoute.self) { _ in
                    MistakeHistoryView()
                }
        }
    }
}

struct QuizConfig: Hashable {
    var title: String
    var questionIds: [String]
    /// 再開位置のキー(年度別・分野別のみ。ランダム等はnil=毎回新規)
    var resumeKey: String?
    /// 開始位置(つづきの場合は保存値)
    var startIndex: Int = 0
}

struct HomeView: View {
    @EnvironmentObject var store: QuestionStore
    @Binding var path: NavigationPath
    @State private var showResetAlert = false
    @State private var showAbout = false
    @State private var showImporter = false
    @State private var showShare = false
    @State private var shareURL: URL?
    @State private var pendingBackup: HistoryBackup?
    @State private var showImportConfirm = false
    @State private var importErrorMessage: String?

    let years = QuestionsData.years
    let categories = STCategory.allCases.map { $0.rawValue }

    /// 年度別・分野別行の進捗情報をまとめて算出する(型推論の負荷分散用)。
    /// start: 再開位置(保存値があれば優先、なければ未解答の先頭)
    private func progress(for qs: [STQuestion], key: String) -> (done: Int, start: Int, resumable: Bool, ids: [String]) {
        let ids = qs.map { $0.id }
        let set = Set(ids)
        let done = store.answers.keys.filter { set.contains($0) }.count
        let saved = store.resumeIndex(for: key)
        let firstGap = ids.firstIndex(where: { store.answers[$0] == nil }) ?? ids.count
        let start: Int
        if saved > 0 && saved < qs.count {
            start = saved
        } else if firstGap < qs.count {
            start = firstGap
        } else {
            start = 0
        }
        return (done, start, start > 0, ids)
    }

    var body: some View {
        List {
            Section("学習状況") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("解答済み \(store.totalAnswered) / \(QuestionsData.all.count)問")
                            .font(.headline)
                        Text(String(format: "正答率 %.0f%%", store.accuracy * 100))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    ProgressView(value: store.accuracy)
                        .frame(width: 100)
                }
                .padding(.vertical, 4)
            }

            Section("モード") {
                Button {
                    let ids = QuestionsData.all.shuffled().prefix(10).map { $0.id }
                    path.append(QuizConfig(title: "ランダム10問", questionIds: Array(ids)))
                } label: {
                    Label("ランダム10問に挑戦", systemImage: "shuffle")
                }
                Button {
                    let ids = QuestionsData.all.shuffled().prefix(25).map { $0.id }
                    path.append(QuizConfig(title: "模擬試験 25問", questionIds: Array(ids)))
                } label: {
                    Label("模擬試験 (25問・40分目安)", systemImage: "timer")
                }
                let wrong = QuestionsData.all.filter { store.isWrong($0) }
                Button {
                    path.append(QuizConfig(title: "苦手問題", questionIds: wrong.map { $0.id }))
                } label: {
                    Label("苦手問題を復習 (\(wrong.count)問)", systemImage: "exclamationmark.triangle")
                }
                .disabled(wrong.isEmpty)
                NavigationLink(value: MistakeRoute()) {
                    Label("間違い履歴 (\(store.everWrongIds.count)問・累計\(store.totalWrongAnswers)回)", systemImage: "clock.arrow.circlepath")
                }
                .disabled(store.everWrongIds.isEmpty)
            }

            Section("年度別") {
                ForEach(years, id: \.self) { y in
                    let qs = QuestionsData.all.filter { $0.year == y }
                    let key = "year:\(y)"
                    let p = progress(for: qs, key: key)
                    let status = p.done > 0
                        ? "\(p.done)/\(qs.count)問済み・正答率\(Int(store.accuracy(for: qs) * 100))%"
                        : "0/\(qs.count)問済み"
                    HStack(alignment: .center, spacing: 8) {
                        Button {
                            path.append(QuizConfig(
                                title: y,
                                questionIds: p.ids,
                                resumeKey: key,
                                startIndex: p.start
                            ))
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(y)
                                Text(status)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if p.resumable {
                                    Text("つづき: \(p.start + 1)問目〜")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if p.resumable {
                            Button("はじめから") {
                                path.append(QuizConfig(
                                    title: y,
                                    questionIds: p.ids,
                                    resumeKey: key,
                                    startIndex: 0
                                ))
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                    .disabled(qs.isEmpty)
                }
            }

            Section("分野別") {
                ForEach(categories, id: \.self) { c in
                    let qs = QuestionsData.all.filter { $0.category == c }
                    let key = "cat:\(c)"
                    let p = progress(for: qs, key: key)
                    let status = p.done > 0
                        ? "\(p.done)/\(qs.count)問済み・正答率\(Int(store.accuracy(for: qs) * 100))%"
                        : "未着手・全\(qs.count)問"
                    HStack(alignment: .center, spacing: 8) {
                        Button {
                            path.append(QuizConfig(
                                title: c,
                                questionIds: p.ids,
                                resumeKey: key,
                                startIndex: p.start
                            ))
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(c)
                                Text(status)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if p.resumable {
                                    Text("つづき: \(p.start + 1)問目〜")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if p.resumable {
                            Button("はじめから") {
                                path.append(QuizConfig(
                                    title: c,
                                    questionIds: p.ids,
                                    resumeKey: key,
                                    startIndex: 0
                                ))
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Section("学習履歴のバックアップ") {
                Text("解答済み \(store.totalAnswered)問・形式バージョン\(HistoryBackup.currentVersion)のJSONで書出し/読込み。問題追加時もID基準で履歴は維持されます。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    do {
                        let data = try store.exportJSON()
                        let fmt = DateFormatter()
                        fmt.dateFormat = "yyyyMMdd-HHmmss"
                        let name = "ST-AM2-history-\(fmt.string(from: Date())).json"
                        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                        try data.write(to: url, options: .atomic)
                        shareURL = url
                        showShare = true
                    } catch {
                        importErrorMessage = "エクスポートに失敗しました。"
                    }
                } label: {
                    Label("履歴をエクスポート(共有)", systemImage: "square.and.arrow.up")
                }
                Button {
                    showImporter = true
                } label: {
                    Label("履歴をインポート", systemImage: "square.and.arrow.down")
                }
            }

            Section("その他") {
                Button("学習履歴をリセット", role: .destructive) {
                    showResetAlert = true
                }
                Button("このアプリについて") {
                    showAbout = true
                }
            }
        }
        .navigationTitle("ST 午前II対策")
        .alert("学習履歴をリセットしますか?", isPresented: $showResetAlert) {
            Button("リセット", role: .destructive) { store.reset() }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL {
                VStack(spacing: 16) {
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ShareLink(item: url) {
                        Label("共有シートを開く", systemImage: "square.and.arrow.up")
                            .font(.headline)
                    }
                    Text("AirDrop・ファイルに保存・メール等でバックアップできます。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
                .presentationDetents([.medium])
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    pendingBackup = try QuestionStore.parseBackup(from: data)
                    showImportConfirm = true
                } catch let e as LocalizedError {
                    importErrorMessage = e.errorDescription
                } catch {
                    importErrorMessage = "ファイルを読めませんでした。"
                }
            case .failure:
                importErrorMessage = "ファイルを選択できませんでした。"
            }
        }
        .confirmationDialog(
            "履歴の取込み",
            isPresented: $showImportConfirm,
            titleVisibility: .visible
        ) {
            Button("結合する(回数を加算)") {
                if let b = pendingBackup { store.importMerge(b) }
                pendingBackup = nil
            }
            Button("置き換える(現在の履歴を破棄)", role: .destructive) {
                if let b = pendingBackup { store.importReplace(b) }
                pendingBackup = nil
            }
            Button("キャンセル", role: .cancel) { pendingBackup = nil }
        } message: {
            if let b = pendingBackup {
                Text("解答済み\(b.answeredCount)問分を取込みます。結合は回数を加算し、問題ごとの正誤はこの端末の記録を優先します。")
            }
        }
        .alert("エラー", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "")
        }
    }
}

struct AboutView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ITストラテジスト試験 午前II対策").font(.title2).bold()
                    Text("収録: 400問 (平成21年度秋期〜令和7年度春期の全16回分・各25問) / 四肢択一 / 解説付き")
                        .font(.subheadline).foregroundColor(.secondary)
                    Divider()
                    Text("出典・利用条件").font(.headline)
                    Text("問題文は独立行政法人情報処理推進機構(IPA)が公開する過去問題を画像認識(Vision)と目視確認で文字起こししたもので、解答はIPAの公式解答例と全問照合済みです。表形式の問題は読みやすい文章に整えています。IPA公開問題の利用条件に基づき、許諾・使用料不要で利用可能です。分類・解説は本アプリのオリジナルです。")
                        .font(.footnote)
                    Text("午前IIは25問・40分・60点以上で通過。本アプリでは年度別・分野別・ランダム・模擬試験・苦手復習・間違い履歴(累積・回数記録・時間/年度/回数ソート)が可能です。年度別・分野別は中断した箇所から再開できます。分からない問題は「わからない」を選ぶと正解に計上されず解説が表示されます。サインイン不要、学習履歴は端末内のみに保存されます。履歴はJSONで書出し/読込みでき、問題追加時もID基準で維持されます。")
                        .font(.footnote)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
