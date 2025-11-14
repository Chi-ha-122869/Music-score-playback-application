import SwiftUI

// MARK: - PDFファイルを表示するSwiftUI用ビュー
// 引数として「PDFファイル名」と「ナビゲーションバーに表示するタイトル」を受け取る。
// 例: PDFViewerView(fileName: "Install", title: "インストール方法")
struct PDFViewerView: View {
    let fileName: String   // バンドル内にあるPDFファイル名（拡張子は不要）
    let title: String      // 画面上部に表示するタイトル（NavigationTitle）
    
    var body: some View {
        VStack {
            // PDFファイルのURLをアプリのバンドル内から探す
            if let url = Bundle.main.url(forResource: fileName, withExtension: "pdf") {
                // 見つかった場合はPDFAnnotatableViewを使って表示
                // → ここでPDFKitを利用して実際のPDFを画面に描画する
                PDFAnnotatableView(url: url)
            } else {
                // ファイルが見つからない場合のエラーメッセージ
                Text("PDFファイルが見つかりません。")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        // NavigationStackまたはNavigationView内で使われる前提
        // 画面上部にPDFの内容タイトルを表示
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline) // タイトルを中央寄せの小さめ表示にする
    }
}
