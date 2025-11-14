import Foundation

// MARK: - 楽譜データを管理するストア（ViewModel的な役割）
// @Publishedを使ってViewと自動連携し、データの追加・削除を即時反映。
// アプリ起動時に自動で読み込み、変更時に自動で保存する。
class ScoreStore: ObservableObject {
    
    // MARK: - 楽譜データ配列
    // Viewで使う全てのScoreModelを保持。
    // @Publishedにより、値が変わるとViewが自動更新される。
    @Published var scores: [ScoreModel] = [] {
        didSet {
            // 楽譜データが変更されるたびに自動で保存
            saveScores()
        }
    }
    
    // MARK: - 保存先ファイルURL
    // アプリごとのドキュメントディレクトリに「scores.json」として保存。
    private var saveURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scores.json")
    }
    
    // MARK: - 初期化処理
    // アプリ起動時に自動的に保存済みデータを読み込む。
    init() {
        loadScores()
    }
    
    // MARK: - 楽譜データを保存
    // ScoreModelの配列をファイルに書き出す。
    // URLは端末依存のため、ファイル名だけをJSONに保存する。
    func saveScores() {
        do {
            // 各ScoreModelを "ファイル名のみ版" に変換してエンコード
            let fileNameOnlyScores = scores.map { $0.fileNameBasedCopy() }
            let data = try JSONEncoder().encode(fileNameOnlyScores)
            
            // JSONデータをドキュメントフォルダに書き込み
            try data.write(to: saveURL)
            print("楽譜データ保存成功")
            
        } catch {
            print("楽譜データ保存失敗: \(error)")
        }
    }
    
    
    // MARK: - 楽譜データを読み込み
    // 保存されたscores.jsonを読み込み、ScoreModelに復元する。
    func loadScores() {
        do {
            // ファイルを読み込み
            let data = try Data(contentsOf: saveURL)
            
            // JSONをデコード（URLではなくファイル名だけの軽量モデル）
            let loadedFileNameModels = try JSONDecoder().decode([ScoreModelFileName].self, from: data)
            
            // ファイル名から実際のファイルURLを再構築
            scores = loadedFileNameModels.map { $0.toScoreModel() }
            
            print("楽譜データ読み込み成功")
            
        } catch {
            // 初回起動やファイルが存在しない場合もここに来る（エラーではない）
            print("楽譜データ読み込み失敗または初期状態: \(error)")
        }
    }
}
