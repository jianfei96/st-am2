# ST 午前II対策

ITストラテジスト試験「午前II」の過去問題を解くための iOS アプリ (SwiftUI) です。
平成21年度秋期〜令和7年度春期の全16回・400問を収録し、全問にオリジナル解説と分野分類を付けています。図表問題は原本から切り出した図版54点を表示します。

> 本アプリは非公式の学習用アプリです。IPA(独立行政法人情報処理推進機構)および試験実施団体とは関係ありません。

## ダウンロード

ビルド済みの IPA は [Releases](https://github.com/jianfei96/st-am2/releases/latest) で配布しています。

- ファイル名は `STApp-<version>-unsigned.ipa` です。**未署名**のため、そのままでは実機にインストールできません。
- Sideloadly / AltStore / SideStore などで Apple ID を使って再署名するか、Xcode でご自身の Team を設定してビルドしてください。
- 対応: iOS 17.0 以降

## 特徴

- **全400問を収録** — 午前II 16回分(各25問)を文字起こしし、解答はIPA公式解答例と全問照合済み
- **全問に4択の選択肢別解説** — 正解の根拠と、各誤答肢が何の説明か(または何が誤りか)を1行ずつ解説
- **図表をそのまま表示** — 表・グラフ・マトリクスなど54点を画像で収録(タップで拡大)
- **計算問題は式と途中経過付き** — DCF/NPV/PBP/LTV/連結売上高/線形計画法/在庫補充量など
- **学習モード** — 年度別、分野別、ランダム10問、模擬試験25問、苦手問題の復習
- **間違い履歴** — 累計の誤答回数・最終誤答日時を記録し、条件で並べ替え
- **中断と再開** — 年度別・分野別は前回の続きから再開可能
- **「わからない」ボタン** — 当てずかずに解説を読む選択肢。正解には計上せず苦手として記録
- **履歴のバックアップ** — 学習履歴をJSONで書き出し/読み込み(端末内保存のみ、サインイン不要)

## 収録分野

| 分野 | 問題数 |
| --- | ---: |
| 経営戦略 | 223 |
| 会計・法務・その他 | 57 |
| システム戦略 | 56 |
| 監査・内部統制・セキュリティ | 29 |
| システム企画・調達 | 24 |
| プロジェクト・サービス | 11 |
| **合計** | **400** |

## ビルド

- Xcode 16 以降
- iOS 17.0 以降
- 依存パッケージなし(追加のライブラリは使用していません)

```sh
git clone https://github.com/jianfei96/st-am2.git
cd st-am2/STApp
open STApp.xcodeproj
```

`STApp` スキームを実機またはシミュレータで実行してください。署名はご自身の Team を設定してください。

コマンドラインでのビルド:

```sh
xcodebuild -project STApp/STApp.xcodeproj -scheme STApp \
  -configuration Release -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

## 構成

```
STApp/
├── STApp.xcodeproj/
└── STApp/
    ├── App.swift            エントリポイント
    ├── ContentView.swift    ホーム画面(モード選択・進捗・バックアップ)
    ├── QuizView.swift       出題・解説・結果画面
    ├── HistoryView.swift    間違い履歴
    ├── Models.swift         問題モデルと分野定義
    ├── QuestionsData.swift  questions.json の読み込み
    ├── QuestionStore.swift  学習履歴の保存(UserDefaults)
    ├── questions.json       問題データ(400問)
    ├── Figures/             図表画像(54点、ファイル名=問題ID)
    └── Assets.xcassets/
```

### questions.json のスキーマ

```json
{
  "id": "2025r07h-01",
  "year": "令和7年度春期",
  "number": 1,
  "question": "問題文",
  "choices": ["アの内容", "イの内容", "ウの内容", "エの内容"],
  "answer": "エ",
  "answerIndex": 3,
  "source": "2025r07h",
  "category": "経営戦略",
  "explanation": "ア × ...\nイ × ...\nウ × ...\nエ ○ ..."
}
```

- `id` は `<年度>-<問番号>`。学習履歴はこのIDをキーに保存されるため、問題を追加しても履歴は維持されます。
- `explanation` は改行区切りで、選択肢ごとに1行(`ア`〜`エ`)。図表問題のみ先頭に `【図表の要点】` の行が付きます。
- `Figures/<id>.png` が存在する問題は、出題画面と結果画面で図表を表示します。

## データの出典と利用条件

- 問題文は、独立行政法人情報処理推進機構(IPA)が公開する ITストラテジスト試験 午前II の過去問題を文字起こしし、表や図版は原本から切り出して収録しています。
- 出典: IPA 独立行政法人情報処理推進機構 公開過去問題
  <https://www.ipa.go.jp/shiken/mondai-kaiotu/index.html>
- IPA の公開問題の利用条件に基づき、許諾・使用料不要で利用しています。問題文・図表の著作権は IPA に帰属します。
- 選択肢別の解説、分野分類、アプリの実装は本プロジェクトのオリジナルです。
- 解答は IPA 公式解答例と照合していますが、解説の内容は公式のものではありません。誤りに気付いた場合は Issue でご指摘ください。

## ライセンス

- ソースコードおよびオリジナル解説: [MIT License](LICENSE)
- 過去問題文・図表: IPA の公開問題利用条件に従います(著作権は IPA に帰属。[NOTICE.md](NOTICE.md) 参照)
