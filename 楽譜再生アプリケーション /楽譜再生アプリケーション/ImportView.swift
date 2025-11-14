import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Keyboard監視クラス
// キーボードの表示・非表示を監視し、ビューの底部マージンを調整するために使用
class KeyboardResponder: ObservableObject {
    @Published var currentHeight: CGFloat = 0  // 現在のキーボード高さ
    private var cancellableSet = Set<AnyCancellable>()
    
    init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .map { $0.height } // キーボードの高さを取得
        
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) } // キーボードが消えたら高さ0に
        
        Publishers.Merge(willShow, willHide)
            .receive(on: RunLoop.main)
            .assign(to: \.currentHeight, on: self)
            .store(in: &cancellableSet)
    }
}
// MARK: - ImportView
struct ImportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var scoreStore: ScoreStore // 楽譜データを管理するストア
    
    var editingScore: ScoreModel? = nil // 編集対象の楽譜（nilなら新規）
    var isEditing: Bool = false // 編集モードかどうか
    
    // MARK: - 入力用State
    @State private var scoreName: String = ""  // 楽譜名
    @State private var pdfParts: [PdfPart] = [] // ← 複数PDFパート対応！（追加）
    @State private var newPdfPartName: String = "" // ← 新しいPDFパート名
    @State private var newPdfURL: URL? = nil // ← 新しく選択されたPDFファイル
    @State private var pdfURL: URL? = nil      // 選択されたPDFファイルURL
    @State private var mp3Parts: [Mp3Part] = [] // パートごとのMP3
    @State private var newPartName: String = "" // 新規追加パート名
    @State private var newMp3URL: URL? = nil   // 新規追加MP3
    @State private var fullMp3URL: URL? = nil  // 全体MP3
    
    // MARK: - ピッカー表示フラグ
    @State private var showPDFPicker = false
    @State private var showMp3Picker = false
    @State private var showFullMp3Picker = false
    
    // MARK: - トースト・アラート
    @State private var successMessage = "読み込みが完了しました！"
    @State private var showSuccessToast = false
    @State private var showErrorAlert = false
    
    // MARK: - フォーカス状態
    @FocusState private var focusedField: FocusField?
    enum FocusField: Hashable { case scoreName, partName ,pdfName}

    
    @StateObject private var keyboard = KeyboardResponder() // キーボード高さ監視
    
    // MARK: - グラデーション
    private var mainGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [.appOrange, .appDeepBlue]), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    // MARK: - ビュー本体
    var body: some View {
        ZStack {
            if showSuccessToast{
                ToastView(message: successMessage)
            }
            mainGradient.ignoresSafeArea()
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 25) {
                        titleView()           // タイトル
                        scoreNameCard().id("scoreName")   // 楽譜名入力
                        pdfPartsCard()     // PDF選択
                        mp3PartsCard().id("mp3Parts")     // パートMP3追加
                        fullMp3Card()         // 全体MP3
                        loadButton()          // 読み込み/保存ボタン
                    }
                    .padding()
                    .padding(.bottom, keyboard.currentHeight + 20) // キーボードに合わせて下マージン
                }
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil } // 背景タップでキーボード閉じる
                .onChange(of: focusedField) { _, newValue in
                    // フォーカスが変わったらスクロール
                    if let field = newValue {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            switch field {
                            case .scoreName: proxy.scrollTo("scoreName", anchor: .top)
                            case .partName: proxy.scrollTo("mp3Parts", anchor: .center)
                            case .pdfName: proxy.scrollTo("pdfParts", anchor: .center)
                            }
                        }
                    }
                }
            }
            
            // MARK: - 成功トースト
            if showSuccessToast {
                VStack {
                    Spacer()
                    Text(successMessage)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.vertical, 30)
                        .padding(.horizontal, 40)
                        .background(
                            LinearGradient(colors: [Color.appAccent, Color.appOrange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.8), lineWidth: 3))
                        .shadow(color: .white.opacity(0.4), radius: 10, x: 0, y: 4)
                        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 6)
                        .transition(.scale.combined(with: .opacity))
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSuccessToast)
        .onAppear {
            // 編集モードなら既存データをセット
            if isEditing, let s = editingScore {
                scoreName = s.name
                pdfParts = s.pdfParts
                mp3Parts = s.mp3Parts
                fullMp3URL = s.fullMp3URL
            }
        }
    }
    
    // MARK: - タイトルビュー
    @ViewBuilder
    private func titleView() -> some View {
        Text(isEditing ? "ファイル編集" : "ファイル読み込み")
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
    }
    
    // MARK: - 楽譜名入力カード
    @ViewBuilder
    private func scoreNameCard() -> some View {
        cardView {
            VStack(alignment: .leading, spacing: 8) {
                Text("楽譜名").font(.headline).foregroundColor(.white.opacity(0.9))
                TextField("楽譜名を入力", text: $scoreName)
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .focused($focusedField, equals: .scoreName)
            }
        }
    }
    
    // MARK: - PDFパートカード（複数対応）
    @ViewBuilder
    private func pdfPartsCard() -> some View {
        cardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("パートごとのPDFファイル")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                
                // 入力行
                HStack(spacing: 10) {
                    // パート名
                    TextField("パート名", text: $newPdfPartName)
                        .padding(10)
                        .background(Color.white.opacity(0.85))
                        .cornerRadius(10)
                        .foregroundColor(.black)
                        .font(.body)
                        .focused($focusedField, equals: .pdfName)
                    
                    // PDF選択ボタン
                    Button(action: { showPDFPicker = true }) {
                        Text(newPdfURL == nil ? "PDF選択" : (newPdfURL!.deletingPathExtension().lastPathComponent.components(separatedBy: "@").first ?? "PDF"))//@からのユニーク名を表示しない
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.appAccent.opacity(0.8))
                    .cornerRadius(10)
                    .foregroundColor(.black)
                    .fileImporter(isPresented: $showPDFPicker, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
                        handleFileImport(result: result) { selected in
                            if let copied = copyToDocuments(from: selected, fileName: selected.lastPathComponent) {
                                newPdfURL = copied
                            }
                        }
                    }
                    
                    //PDFファイルを選んだら押せる
                    let canAdd = newPdfURL != nil
                    
                    Button("追加") {
                        guard let u = newPdfURL else { return }
                        
                        // 名前が空なら → ファイル名をパート名として採用
                        let displayName: String
                        if newPdfPartName.trimmingCharacters(in: .whitespaces).isEmpty {
                            displayName = u.deletingPathExtension().lastPathComponent.components(separatedBy: "@").first ?? "不明"//@からのユニーク名を表示しない
                        } else {
                            displayName = newPdfPartName
                        }
                        
                        pdfParts.append(PdfPart(id: UUID(), partName: displayName, pdfURL: u))
                        newPdfPartName = ""
                        newPdfURL = nil
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(canAdd ? Color.green : Color.gray.opacity(0.3))
                    .cornerRadius(14)
                    .foregroundColor(canAdd ? .white : .black)
                    .disabled(!canAdd)
                }
                
                PartListView(
                    parts: $pdfParts,
                    label: { part in
                        "\(part.partName): \(cleanFileName(from: part.pdfURL.lastPathComponent))"
                    }
                )
            }
        }
    }

    // MARK: - パートごとのMP3カード
    @ViewBuilder
    private func mp3PartsCard() -> some View {
        cardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("パートごとのMP3ファイル")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                
                HStack(spacing: 10) {
                    TextField("パート名", text: $newPartName)
                        .padding(10)
                        .background(Color.white.opacity(0.85))
                        .cornerRadius(10)
                        .foregroundColor(.black)
                        .font(.body)
                        .focused($focusedField, equals: .partName)
                    
                    // MP3選択ボタン
                    Button(action: { showMp3Picker = true }) {
                        Text(newMp3URL == nil ? "mp3選択" : (newMp3URL!.deletingPathExtension().lastPathComponent.components(separatedBy: "@").first ?? "mp3"))//@からのユニーク名を表示しない
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.appAccent.opacity(0.8))
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .fileImporter(isPresented: $showMp3Picker, allowedContentTypes: [.mp3], allowsMultipleSelection: false) { result in
                        handleFileImport(result: result) { selected in
                            if let copied = copyToDocuments(from: selected, fileName: selected.lastPathComponent) {
                                newMp3URL = copied
                            }
                        }
                    }
                    
                    //ファイル選択さえあればOK
                    let canAdd = newMp3URL != nil
                    
                    Button("追加") {
                        guard let u = newMp3URL else { return }
                        
                        // 名前が空ならファイル名をそのまま使用
                        let displayName: String
                        if newPartName.trimmingCharacters(in: .whitespaces).isEmpty {
                            displayName = u.deletingPathExtension().lastPathComponent.components(separatedBy: "@").first ?? "不明"//@からのユニーク名を表示しない
                        } else {
                            displayName = newPartName
                        }
                        
                        mp3Parts.append(Mp3Part(id: UUID(), partName: displayName, mp3URL: u))
                        newPartName = ""
                        newMp3URL = nil
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(canAdd ? Color.green : Color.gray.opacity(0.3))
                    .cornerRadius(14)
                    .foregroundColor(canAdd ? .white : .black)
                    .disabled(!canAdd)
                }
                
                PartListView(
                    parts: $mp3Parts,
                    label: { part in
                        "\(part.partName): \(cleanFileName(from: part.mp3URL.lastPathComponent))"
                    }
                )
            }
        }
    }

    // MARK: - 全体MP3カード
    @ViewBuilder
    private func fullMp3Card() -> some View {
        cardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("全体MP3ファイル").font(.headline).foregroundColor(.white.opacity(0.9))
                
                Button(action: { showFullMp3Picker = true }) {
                    HStack {
                        Image(systemName: "waveform").foregroundColor(.white.opacity(0.8))
                        Text(fullMp3URL == nil ? "全体mp3ファイルを選択" : (fullMp3URL!.deletingPathExtension().lastPathComponent.components(separatedBy: "@").first ?? ""))//@からのユニーク名を表示しない
                            .font(.body).foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(10)
                }
                .fileImporter(isPresented: $showFullMp3Picker, allowedContentTypes: [.mp3], allowsMultipleSelection: false) { result in
                    handleFileImport(result: result) { selected in
                        if let copied = copyToDocuments(from: selected, fileName: selected.lastPathComponent) {
                            fullMp3URL = copied
                        }
                    }
                }
            }
        }
    }
    //MARK: PDFとMP3の既存パートリスト表示
    // ファイル名のユニークIDを除去（例： "楽曲名-Soprano＠935E8295..." → "楽曲名-Soprano"）
    private func cleanFileName(from fileName: String) -> String {
        if let range = fileName.range(of: "@[A-F0-9-]+", options: .regularExpression) {
            return String(fileName[..<range.lowerBound])
        }
        return fileName
    }
    /// PDFやMP3など共通で使える「パートリスト表示コンポーネント」
    struct PartListView<Part: Identifiable>: View {
        @Binding var parts: [Part]
        let label: (Part) -> String  // 表示用の文字列を生成するクロージャ
        
        var body: some View {
            if !parts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(parts.enumerated()), id: \.element.id) { index, part in
                        HStack {
                            // 表示ラベル（例: "ソプラノ: SongName-Soprano"）
                            Text(label(part))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // 並び替えボタン（内部定義）
                            HStack(spacing: 6) {
                                Button(action: {
                                    if index > 0 {
                                        withAnimation {
                                            parts.swapAt(index, index - 1)
                                        }
                                    }
                                }) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundColor(index == 0 ? .gray.opacity(0.5) : .appAccent)
                                        .font(.title3)
                                }
                                .disabled(index == 0)
                                
                                Button(action: {
                                    if index < parts.count - 1 {
                                        withAnimation {
                                            parts.swapAt(index, index + 1)
                                        }
                                    }
                                }) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(index == parts.count - 1 ? .gray.opacity(0.5) : .appAccent)
                                        .font(.title3)
                                }
                                .disabled(index == parts.count - 1)
                            }
                            
                            // 削除ボタン
                            Button("削除") {
                                withAnimation {
                                    parts.removeAll { $0.id == part.id }
                                }
                            }
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.leading, 20)
                        }
                        Divider().background(Color.white.opacity(0.3))
                    }
                }
                .padding(.top, 6)
            }
        }
    }
    //MARK: 読み込みボタン
    @ViewBuilder
    private func loadButton() -> some View {
        let isReady = !(scoreName.isEmpty || pdfParts.isEmpty || mp3Parts.isEmpty || fullMp3URL == nil)
        
        let loadBackground = isReady
        ? AnyView(LinearGradient(colors: [Color.appOrange, Color.appAccent.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
        : AnyView(Color.gray.opacity(0.5))
        
        Button {
            guard !pdfParts.isEmpty, let full = fullMp3URL, !mp3Parts.isEmpty else {
                withAnimation { showErrorAlert = true }
                return
            }
            
            let displayName = scoreName.isEmpty
            ? (pdfParts.first?.partName ?? "未命名")
            : scoreName
            
            let newScore = ScoreModel(
                id: editingScore?.id ?? UUID(),
                name: displayName,
                pdfParts: pdfParts,
                mp3Parts: mp3Parts,
                fullMp3URL: full,
                lastOpened: nil
            )
            
            if isEditing, let editingScore {
                if let index = scoreStore.scores.firstIndex(where: { $0.id == editingScore.id }) {
                    scoreStore.scores[index] = newScore
                }
                successMessage = "保存が完了しました！"
            } else {
                scoreStore.scores.append(newScore)
                successMessage = "読み込みが完了しました！"
            }
            
            withAnimation { showSuccessToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation { showSuccessToast = false }
                dismiss()
            }
        } label: {
            Text(isEditing ? "保存する" : "読み込む")
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(loadBackground)
                .cornerRadius(16)
                .foregroundStyle(LinearGradient(colors: [.white.opacity(0.9), .white], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color.white.opacity(0.3), radius: 2)
                .scaleEffect(isReady ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isReady)
        }
        .disabled(!isReady)
        .alert("もう一度ファイルを入れ直してください。", isPresented: $showErrorAlert) {
            Button("OK") {
                pdfParts = []
                mp3Parts = []
                fullMp3URL = nil
            }
        }
    }

    
    // MARK: - 共通カードスタイル
    @ViewBuilder
    private func cardView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .background(LinearGradient(colors: [Color.white.opacity(0.25), Color.blue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(20)
    }
    
    // MARK: - fileImporter共通処理
    private func handleFileImport(result: Result<[URL], Error>, handler: (URL) -> Void) {
        if let selected = try? result.get().first {
            // コピーは呼び出し側で行う
            handler(selected)
        }
    }
    
    private func pdfDisplayName(from url: URL?) -> String? {
        guard let u = url else { return nil }
        // ファイル名から拡張子を除き、先頭の識別名を取得
        return u.deletingPathExtension().lastPathComponent.components(separatedBy: "/").first
    }
}

// MARK: - ファイルコピー関数
func copyToDocuments(from url: URL, fileName: String) -> URL? {
    let fileManager = FileManager.default
    do {
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileExtension = (fileName as NSString).pathExtension
        let baseName = (fileName as NSString).deletingPathExtension
        let uniqueFileName = "\(baseName)@\(UUID().uuidString).\(fileExtension)"//@からUUIDのユニーク名をつける
        let destURL = docsURL.appendingPathComponent(uniqueFileName)
        
        // セキュリティスコープのアクセス
        guard url.startAccessingSecurityScopedResource() else {
            print("アクセス権が取れません: \(url)")
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        try fileManager.copyItem(at: url, to: destURL)
        return destURL
    } catch {
        print("コピー失敗: \(error)")
        return nil
    }
}
