import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

// MARK: - その他画面（データ共有や取込、PDF説明ページなどを表示）
// この画面ではユーザーが以下の操作を行える：
// ・楽譜データの共有（ZIPにまとめてエクスポート）
// ・楽譜データの取り込み（ZIPをインポート）
// ・MuseScore関連のPDFガイドを閲覧
struct OtherView: View {
    // --- 状態管理用の@Stateプロパティ ---
    @State private var showShareMenu = false      // 「共有メニュー」シートの表示フラグ
    @State private var showSelectSheet = false    // 「共有するデータ選択」シートの表示フラグ
    @State private var showImporter = false       // ZIPファイル取り込みダイアログ表示フラグ
    @State private var selectedScore: ScoreModel? // 共有対象として選ばれたスコア（1件）
    @State private var shareItem: IdentifiableURL?// ActivityViewに渡す共有用URL（ZIP）
    @State private var goToLibrary = false        // 取り込み完了後にライブラリへ自動遷移するフラグ
    
    @EnvironmentObject var scoreStore: ScoreStore // 楽譜データ全体を管理するストア（アプリ全体で共有）
    
    // --- トーストメッセージ用 ---
    @State private var successMessage = ""        // トーストに表示するメッセージ内容
    @State private var showSuccessToast = false   // トーストを表示中かどうか
    
    var body: some View {
        ZStack {
            // ===== 背景グラデーション（アプリ共通デザイン） =====
            LinearGradient(
                gradient: Gradient(colors: [Color.appOrange, Color.appDeepBlue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // ===== 画面全体をスクロール可能に =====
            ScrollView {
                VStack(spacing: 25) {
                    // ===== タイトル（「その他」） =====
                    Text("その他")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(
                            colors: [.appAccent, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing))
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 2, y: 2)
                    
                    // ===== 「共有・取り込み」ボタン（TopButton共通デザイン） =====
                    Button { showShareMenu = true } label: {
                        TopButton(title: "共有", subtitle: "データの共有・取り込み")
                    }
                    // ===== 「共有メニュー」シート（フル画面シート） =====
                    .sheet(isPresented: $showShareMenu) {
                        ZStack {
                            // --- 背景（深いブルー＋オレンジのグラデーション） ---
                            LinearGradient(
                                gradient: Gradient(colors: [Color.appDeepBlue, Color.appOrange.opacity(0.6)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .ignoresSafeArea()
                            
                            // --- シート内のUI構成 ---
                            VStack(spacing: 30) {
                                Spacer()
                                
                                // --- 「共有メニュー」タイトル ---
                                Text("共有メニュー")
                                    .font(.system(size: 40, weight: .black, design: .rounded))
                                    .foregroundStyle(LinearGradient(
                                        colors: [.appAccent, .white.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing))
                                    .shadow(color: .black.opacity(0.4), radius: 4, x: 2, y: 2)
                                    .padding(.top, 30)
                                
                                // --- 「データを共有」ボタン ---
                                Button {
                                    // ①シートを閉じて
                                    showShareMenu = false
                                    // ②少し待ってから（アニメーションずれ防止）選択シートを開く
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showSelectSheet = true
                                    }
                                } label: {
                                    Text("データを共有")
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 100) // ⬅️ 通常より少し縦長に
                                        .background(
                                            LinearGradient(
                                                colors: [Color.appAccent, Color.appDeepBlue],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .cornerRadius(18)
                                        .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
                                }
                                .padding(.horizontal, 20) // 横を広く取って中央に配置
                                
                                // --- 「データを取り込む」ボタン ---
                                Button {
                                    // ①シートを閉じる
                                    showShareMenu = false
                                    // ②少し待ってからZIP選択を開く
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showImporter = true
                                    }
                                } label: {
                                    Text("データを取り込む")
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 100)
                                        .background(
                                            LinearGradient(
                                                colors: [Color.appOrange, Color.appDeepBlue],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .cornerRadius(18)
                                        .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
                                }
                                .padding(.horizontal, 20)
                                
                                // --- キャンセルボタン ---
                                Button(role: .cancel) {
                                    showShareMenu = false
                                } label: {
                                    Text("キャンセル")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.top, 10)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 40)
                        }
                    }
                    
                    // ===== PDFマニュアルへのナビリンク =====
                    // MuseScore Studio のインストール手順PDFを開く
                    NavigationLink(destination: PDFViewerView(fileName: "Install", title: "MuseScore Studioのインストール方法")) {
                        TopButton(title: "MuseScoreの\nインストール方法", subtitle: "導入手順を説明")
                    }
                    
                    // PDF・MP3エクスポート手順のPDFを開く
                    NavigationLink(destination: PDFViewerView(fileName: "Export", title: "PDF・MP3のエクスポート方法")) {
                        TopButton(title: "PDF・MP3の\nエクスポート方法", subtitle: "出力手順を説明")
                    }
                    
                    Spacer()
                    
                    // ===== フッター（免責文） =====
                    Text("""
                「MuseScore」および「MuseScore Studio」は、Muse Groupまたはその関連会社の登録商標です。
                本アプリはMuse Groupとは提携しておらず、MuseScoreの使用方法を案内するための非公式ガイドです。
                """)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .padding()
            
            // ===== トースト表示（インポート・エクスポート成功メッセージ） =====
            if showSuccessToast {
                ToastView(message: successMessage)
            }
        }
        // ===== データ選択シート（共有用） =====
        .sheet(isPresented: $showSelectSheet) {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    gradient: Gradient(colors: [Color.appDeepBlue, Color.appOrange.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer().frame(height: 30)
                    
                    // シートのタイトル
                    Text("共有するデータを選択")
                        .font(.system(size: 35, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.appAccent, .white.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 2, y: 2)
                        .padding(.top, 30)
                    
                    // ===== スコア一覧をスクロール表示 =====
                    ScrollView {
                        VStack(spacing: 15) {
                            //lastOpenedの新しい順に並べ替え
                            let sortedScores = scoreStore.scores.sorted {
                                // nil（未開封）は一番下に来るように distantPast 扱い
                                ($0.lastOpened ?? .distantPast) > ($1.lastOpened ?? .distantPast)
                            }
                            
                            // 登録済みスコアをすべて表示（並び替え後のリストを使用）
                            ForEach(sortedScores) { score in
                                Button {
                                    // 選択されたスコアを記録
                                    selectedScore = score
                                } label: {
                                    HStack {
                                        Text(score.name)
                                            .font(.system(size: 20, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                        Spacer()
                                        
                                        // 現在選択中のスコアにはチェックマークを表示
                                        if selectedScore?.id == score.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.appAccent)
                                                .font(.title2)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        selectedScore?.id == score.id
                                        ? Color.white.opacity(0.4) // 選択中：少し明るく
                                        : Color.white.opacity(0.3) // 通常：やや暗め
                                    )
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    
                    // ===== 「決定」ボタン =====
                    Button {
                        // 選択されていればZIP作成を実行
                        if let selected = selectedScore {
                            shareItem = exportScoreAsIdentifiableZip(score: selected)
                        }
                        showSelectSheet = false // シートを閉じる
                    } label: {
                        let canDecide = selectedScore != nil // 選択されているか
                        
                        Text("決定")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 20)
                            .background(
                                LinearGradient(
                                    colors: canDecide
                                    ? [Color.appAccent, Color.appOrange.opacity(0.9)] // 有効時：鮮やか
                                    : [Color.gray.opacity(0.4), Color.gray.opacity(0.6)], // 無効時：グレー
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white.opacity(0.9), .white],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.white.opacity(0.25), radius: 2, x: 0, y: 2)
                            .scaleEffect(canDecide ? 1.05 : 1.0) // 選択時に少し拡大
                            .animation(.easeInOut(duration: 0.3), value: canDecide)
                    }
                    .disabled(selectedScore == nil)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
            }
        }
        
        
        // ===== ZIP取り込み =====
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType.zip], // ZIPファイルのみ選択可能
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importFromZip(url: url) // ZIP解凍処理へ
                }
            case .failure(let error):
                // 取り込み失敗時のメッセージ表示
                successMessage = "取り込みに失敗しました: \(error.localizedDescription)"
                withAnimation { showSuccessToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation { showSuccessToast = false }
                }
            }
        }
        
        // ===== 取り込み後、自動でライブラリ画面に遷移 =====
        .navigationDestination(isPresented: $goToLibrary) {
            SheetListView()
                .environmentObject(scoreStore)
        }
        
        // ===== 共有処理（ActivityViewでシェア画面を表示） =====
        .sheet(item: $shareItem) { item in
            ActivityView(activityItems: [item.url]) {
                // シェア完了後のトーストメッセージ
                successMessage = "\(item.url.lastPathComponent) を共有しました！"
                withAnimation { showSuccessToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                    withAnimation { showSuccessToast = false }
                }
            }
        }
    }
    
    
    // MARK: - ZIP作成（スコアを共有用ZIPにまとめる）
    private func exportScoreAsIdentifiableZip(score: ScoreModel) -> IdentifiableURL? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tempDir = docs.appendingPathComponent("ExportTemp") // 一時フォルダ
        let zipURL = docs.appendingPathComponent("\(score.name).zip") // 出力先ZIP
        
        do {
            // 古い一時フォルダを削除して再作成
            try? fm.removeItem(at: tempDir)
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // ===== score.jsonを作成 =====
            // モデル情報をJSONとして保存（譜面データのメタ情報）
            let fileNameModel = score.fileNameBasedCopy()
            let jsonData = try JSONEncoder().encode(fileNameModel)
            try jsonData.write(to: tempDir.appendingPathComponent("score.json"))
            
            // ===== 各PDFファイルをコピー =====
            for pdf in score.pdfParts {
                let dest = tempDir.appendingPathComponent(pdf.pdfURL.lastPathComponent)
                if fm.fileExists(atPath: pdf.pdfURL.path) {
                    try fm.copyItem(at: pdf.pdfURL, to: dest)
                }
            }
            
            // ===== 各MP3ファイルをコピー =====
            for mp3 in score.mp3Parts {
                let dest = tempDir.appendingPathComponent(mp3.mp3URL.lastPathComponent)
                if fm.fileExists(atPath: mp3.mp3URL.path) {
                    try fm.copyItem(at: mp3.mp3URL, to: dest)
                }
            }
            
            // ===== 全体演奏MP3（フル音源）もコピー =====
            if let full = score.fullMp3URL {
                let dest = tempDir.appendingPathComponent(full.lastPathComponent)
                if fm.fileExists(atPath: full.path) {
                    try fm.copyItem(at: full, to: dest)
                }
            }
            
            // 既存のZIPがあれば削除して再作成
            try? fm.removeItem(at: zipURL)
            try fm.zipItem(at: tempDir, to: zipURL)
            
            // 正常終了 → ZIPファイルのURLを返す
            return IdentifiableURL(url: zipURL)
        } catch {
            // エラー時はトースト表示
            successMessage = "エクスポートに失敗しました：\(error.localizedDescription)"
            withAnimation { showSuccessToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation { showSuccessToast = false }
            }
            return nil
        }
    }
    
    
    // MARK: - ZIP読み込み（取り込み処理）
    private func importFromZip(url: URL) {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // 一時作業フォルダをUUID付きで生成（重複防止）
        let workDir = docs.appendingPathComponent("ImportedTemp_\(UUID().uuidString)")
        
        do {
            // 他アプリのファイルにアクセスする権限を取得
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "アクセス権が取れません"])
            }
            defer { url.stopAccessingSecurityScopedResource() } // 最後に必ず解除
            
            // 作業ディレクトリを初期化
            try? fm.removeItem(at: workDir)
            try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
            
            // ZIPをローカルにコピーして展開
            let localZip = workDir.appendingPathComponent(url.lastPathComponent)
            try fm.copyItem(at: url, to: localZip)
            try fm.unzipItem(at: localZip, to: workDir)
            
            // JSONファイルを探して読み込み
            guard let jsonURL = findFile(named: "score.json", in: workDir) else {
                throw NSError(domain: "ImportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "score.jsonが見つかりません"])
            }
            let jsonData = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            let fileNameModel = try decoder.decode(ScoreModelFileName.self, from: jsonData)
            
            // ===== 各PDF・MP3をコピーしてモデルを再構築 =====
            var pdfParts: [PdfPart] = []
            for p in fileNameModel.pdfParts {
                if let src = findFile(named: p.fileName, in: workDir) {
                    let dest = uniqueDestURL(for: docs.appendingPathComponent(p.fileName), fileManager: fm)
                    try? fm.copyItem(at: src, to: dest)
                    pdfParts.append(PdfPart(id: UUID(), partName: p.partName, pdfURL: dest))
                }
            }
            
            var mp3Parts: [Mp3Part] = []
            for p in fileNameModel.mp3Parts {
                if let src = findFile(named: p.fileName, in: workDir) {
                    let dest = uniqueDestURL(for: docs.appendingPathComponent(p.fileName), fileManager: fm)
                    try? fm.copyItem(at: src, to: dest)
                    mp3Parts.append(Mp3Part(id: UUID(), partName: p.partName, mp3URL: dest))
                }
            }
            
            // 全体MP3も同様にコピー
            var fullMp3URL: URL? = nil
            if let fullName = fileNameModel.fullMp3FileName,
               let src = findFile(named: fullName, in: workDir) {
                let dest = uniqueDestURL(for: docs.appendingPathComponent(fullName), fileManager: fm)
                try? fm.copyItem(at: src, to: dest)
                fullMp3URL = dest
            }
            
            // 新しいScoreModelを作成して保存
            let newModel = ScoreModel(
                id: UUID(),
                name: fileNameModel.name,
                pdfParts: pdfParts,
                mp3Parts: mp3Parts,
                fullMp3URL: fullMp3URL,
                lastOpened: nil
            )
            
            DispatchQueue.main.async {
                scoreStore.scores.append(newModel)
                scoreStore.saveScores()
                
                // トーストで成功表示 + ライブラリへ遷移
                successMessage = "\(newModel.name) を取り込みました！"
                withAnimation { showSuccessToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        showSuccessToast = false
                        goToLibrary = true
                    }
                }
            }
        } catch {
            // 失敗時の処理
            DispatchQueue.main.async {
                successMessage = "取り込みに失敗しました: \(error.localizedDescription)"
                withAnimation { showSuccessToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showSuccessToast = false }
                }
            }
        }
    }
    
    
    // MARK: - ディレクトリ内から指定ファイルを探す
    private func findFile(named fileName: String, in directory: URL) -> URL? {
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent == fileName {
                    return fileURL
                }
            }
        }
        return nil
    }
    
    // MARK: - 重複ファイルを避けるためのURL生成
    private func uniqueDestURL(for proposedURL: URL, fileManager fm: FileManager) -> URL {
        var dest = proposedURL
        var idx = 1
        // 同名ファイルがある場合は「_1」「_2」などを付けてリネーム
        while fm.fileExists(atPath: dest.path) {
            let base = proposedURL.deletingPathExtension().lastPathComponent
            let ext = proposedURL.pathExtension
            let parent = proposedURL.deletingLastPathComponent()
            dest = parent.appendingPathComponent("\(base)_\(idx).\(ext)")
            idx += 1
        }
        return dest
    }
}

// MARK: - ActivityView（シェア画面をUIKitで実装）
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any] // 共有対象（今回はZIPファイル）
    let completion: (() -> Void)? // 完了時のクロージャ
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        // シェア完了時にcompletionを呼び出す
        controller.completionWithItemsHandler = { _, _, _, _ in
            completion?()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - IdentifiableURL（URLをIdentifiableとして扱うための構造体）
struct IdentifiableURL: Identifiable {
    let id = UUID() // 一意の識別子
    let url: URL    // 実際のファイルURL
}
