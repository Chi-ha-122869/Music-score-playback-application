import SwiftUI

// MARK: - 楽譜一覧画面（SheetListView）
// 楽譜の一覧表示・編集・削除・再生（PlayerViewへの遷移）を担当。
// ImportViewで登録したScoreModelをScoreStoreから読み取り、カードとして一覧表示する。

struct SheetListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var scoreStore: ScoreStore // ScoreModelのリストを共有
    
    // MARK: - 状態管理用プロパティ
    @State private var selectedScore: ScoreModel? = nil // 選択された楽譜（遷移用）
    @State private var isEditMode = false              // 編集モードON/OFF
    @State private var isDeleteMode = false            // 削除モードON/OFF
    @State private var scoreToDelete: ScoreModel? = nil // 削除対象
    @State private var showDeleteAlert = false          // 削除確認アラート表示フラグ
    @State private var showingAddSheet = false
    
    // MARK: - 日付グループ化ロジック
    private var groupedScores: [String: [ScoreModel]] {
        let now = Date()
        let calendar = Calendar.current
        
        // まずグループ分け
        var groups = Dictionary(grouping: scoreStore.scores) { score in
            guard let lastOpened = score.lastOpened else {
                return "未閲覧"
            }
            let days = calendar.dateComponents([.day], from: lastOpened, to: now).day ?? 0
            
            if days == 0 {
                return "今日"
            } else if days <= 3 {
                return "3日前"
            } else if days <= 7 {
                return "1週間前"
            } else {
                return "それ以前"
            }
        }
        //各グループの中を「lastOpenedが新しい順」にソート
        for key in groups.keys {
            groups[key]?.sort { (a, b) in
                (a.lastOpened ?? .distantPast) > (b.lastOpened ?? .distantPast)
            }
        }
        return groups
    }
    // MARK: - グループの表示順
    private func sortDateLabel(_ a: String, _ b: String) -> Bool {
        let order = ["未閲覧","今日", "3日前", "1週間前", "それ以前"]
        return order.firstIndex(of: a) ?? 99 < order.firstIndex(of: b) ?? 99
    }
    

    var body: some View {
        ZStack {
            // MARK: - 背景（TopViewと統一したグラデーション）
            LinearGradient(
                gradient: Gradient(colors: [.appOrange, .appDeepBlue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) { // VStack間隔を20に設定（全体の見た目を整える）
                
                // MARK: - タイトル部分
                Text("楽譜ライブラリ")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.appAccent, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 2, y: 2)
                
                HStack {
                    Spacer()
                    // 編集ボタン
                    Button(isEditMode ? "完了" : "編集") {
                        isEditMode.toggle()
                        isDeleteMode = false
                    }
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isEditMode ? .cyan : .appAccent)
                    .if(isEditMode) { $0.modifier(OutlinedText(color: .white, thickness: 0.6, opacity: 0.6)) }
                    .padding(.horizontal, 10)
                    
                    Spacer()
                    // 削除ボタン
                    Button(isDeleteMode ? "終了" : "削除") {
                        isDeleteMode.toggle()
                        isEditMode = false
                    }
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isDeleteMode ? .purple : .appAccent)
                    .if(isDeleteMode) { $0.modifier(OutlinedText(color: .white, thickness: 0.6, opacity: 0.6)) }
                    .padding(.trailing, 20)
                    Spacer()
                }
                .animation(.none, value: isEditMode)
                .animation(.none, value: isDeleteMode)
                .padding(.bottom, 2)
                
                

                
                // MARK: - コンテンツ部
                if scoreStore.scores.isEmpty {
                    // 楽譜未登録時のプレースホルダー表示
                    Spacer()
                    Text("まだ楽譜が登録されていません。")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.headline)
                    Text("読み込み画面からPDFとMP3を登録してください。")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.subheadline)
                    Spacer()
                } else {
                    // 登録済み楽譜がある場合は一覧表示
                    ScrollView {
                        VStack(alignment: .leading, spacing: 30) {
                            ForEach(groupedScores.keys.sorted(by: sortDateLabel), id: \.self) { key in
                                VStack(alignment: .leading, spacing: 10) {
                                    // グループタイトル（例: 今日, 3日前, 1週間前, それ以前）
                                    Text(key)
                                        .font(.headline.bold())
                                        .foregroundColor(.white)
                                        .padding(.leading, 20)
                                    
                                    ForEach(groupedScores[key] ?? []) { score in
                                        Button(action: {
                                            if isDeleteMode {
                                                scoreToDelete = score
                                                showDeleteAlert = true
                                            } else {
                                                //閲覧日時を更新
                                                if let index = scoreStore.scores.firstIndex(where: { $0.id == score.id }) {
                                                    scoreStore.scores[index].lastOpened = Date()
                                                    scoreStore.saveScores() // ← もし保存関数があるならここで呼ぶ
                                                }
                                                
                                                selectedScore = score
                                            }
                                        }) {
                                            ScoreCardView(score: score, isDeleteMode: isDeleteMode, isEditMode: isEditMode)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        // MARK: - Navigation遷移設定
        .navigationDestination(item: $selectedScore) { score in
            if isEditMode {
                // 編集モード中はImportView（楽譜編集画面）へ遷移
                ImportView(editingScore: score, isEditing: true)
                    .environmentObject(scoreStore)
            } else {
                // 通常モードはPlayerView（再生画面）へ遷移
                PlayerView(score: score)
            }
        }
        // MARK: - 削除アラート
        .alert("『\(scoreToDelete?.name ?? "不明な楽譜")』\nこの楽譜を本当に削除しますか？", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                if let score = scoreToDelete {
                    // 直接 FileManager.default を使う
                    for pdfPart in score.pdfParts {
                        if FileManager.default.fileExists(atPath: pdfPart.pdfURL.path) {
                            try? FileManager.default.removeItem(at: pdfPart.pdfURL)
                        }
                    }
                    // ---- ファイル削除処理 ----
                    // 各PDFパートを削除
                    for pdfPart in score.pdfParts {
                        if FileManager.default.fileExists(atPath: pdfPart.pdfURL.path) {
                            try? FileManager.default.removeItem(at: pdfPart.pdfURL)
                        }
                    }
                    
                    // 全体MP3削除
                    if let mp3 = score.fullMp3URL, FileManager.default.fileExists(atPath: mp3.path) {
                        try? FileManager.default.removeItem(at: mp3)
                    }
                    
                    // 各パートMP3削除
                    for part in score.mp3Parts {
                        if FileManager.default.fileExists(atPath: part.mp3URL.path) {
                            try? FileManager.default.removeItem(at: part.mp3URL)
                        }
                    }
                    
                    // ---- ScoreStoreリストから削除 ----
                    scoreStore.scores.removeAll { $0.id == score.id }
                    scoreToDelete = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                // キャンセル時は選択解除のみ
                scoreToDelete = nil
            }
        }
    }
}
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
struct OutlinedText: ViewModifier {
    var color: Color = .white
    var thickness: CGFloat = 0.6
    var opacity: Double = 0.6
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(opacity), radius: 0, x: thickness, y: 0)
            .shadow(color: color.opacity(opacity), radius: 0, x: -thickness, y: 0)
            .shadow(color: color.opacity(opacity), radius: 0, x: 0, y: thickness)
            .shadow(color: color.opacity(opacity), radius: 0, x: 0, y: -thickness)
        // 斜め方向はやや弱めで、立体感を減らす
            .shadow(color: color.opacity(opacity * 0.7), radius: 0, x: thickness, y: thickness)
            .shadow(color: color.opacity(opacity * 0.7), radius: 0, x: -thickness, y: thickness)
            .shadow(color: color.opacity(opacity * 0.7), radius: 0, x: thickness, y: -thickness)
            .shadow(color: color.opacity(opacity * 0.7), radius: 0, x: -thickness, y: -thickness)
    }
}
// MARK: - ScoreCardView
// 個々の楽譜カードを表示。モードによってデザインを変化させる。

struct ScoreCardView: View {
    let score: ScoreModel
    let isDeleteMode: Bool
    let isEditMode: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            // MARK: - カード左側アイコン
            VStack {
                Image(systemName:
                        isDeleteMode ? "trash.circle.fill" : // 削除モードアイコン
                      (isEditMode ? "pencil.circle.fill" : "doc.richtext.fill")) // 編集・通常モード
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundColor(
                    isDeleteMode ? .purple :
                        (isEditMode ? .cyan : .appAccent)
                )
            }
            .padding(.leading, 10)
            
            // MARK: - カード中央テキスト情報
            VStack(alignment: .leading, spacing: 4) {
                Text(score.name) // 楽譜名
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("パート数: \(score.mp3Parts.count)") // 登録パート数
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                // 下部ラベル（モード別の説明テキスト）
                Text(isEditMode ? "タップで編集" :
                        (isDeleteMode ? "タップで削除" : "タップで再生"))
                .font(.caption2)
                .foregroundColor(
                    isDeleteMode ? .purple :
                        (isEditMode ? .cyan : .appAccent)
                )
            }
            
            Spacer()
            
            // MARK: - カード右端のアイコン（操作インジケータ）
            Image(systemName:
                    isDeleteMode ? "xmark.circle.fill" : // 削除マーク
                  (isEditMode ? "arrow.right.circle.fill" : "play.circle.fill")) // 編集 or 再生アイコン
            .font(.title2)
            .foregroundColor(
                isDeleteMode ? .purple :
                    (isEditMode ? .cyan : .appAccent)
            )
            .padding(.trailing, 15)
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .background(
            // カード背景（TopButtonと統一感のあるグラデーション）
            LinearGradient(
                colors: [
                    Color.appDeepBlue.opacity(0.8),
                    Color.appDeepBlue.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.3), radius: 6, x: 4, y: 4)
        .overlay(
            // モードに応じて枠線を変化させる（視覚的フィードバック）
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    isDeleteMode ? Color.purple :
                        (isEditMode ? Color.cyan : Color.appAccent.opacity(0.5)),
                    lineWidth: isDeleteMode ? 3 : 1.5
                )
        )
    }
}
