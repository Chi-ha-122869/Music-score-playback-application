import SwiftUI
import PDFKit

// MARK: - SwiftUI上でPDFを表示するView
// PDFKit（UIKitのPDF表示ライブラリ）をSwiftUIから使えるようにラップしている。
// PDFAnnotatableView は、単に PDFKitRepresentedView をラップしているだけのシンプルな構造。
struct PDFAnnotatableView: View {
    let url: URL // 表示するPDFファイルのURL
    var displayDirection: PDFDisplayDirection = .vertical //横方向に表示させる
    
    var body: some View {
        // UIKitのPDFViewをSwiftUIで利用するためのRepresentableを呼び出す
        PDFKitRepresentedView(url: url,displayDirection: displayDirection)
            .ignoresSafeArea() // 端までPDFを広げて表示
    }
}

// MARK: - UIViewRepresentable
// UIKitの `PDFView`（PDFKit）をSwiftUIで使うためのブリッジ。
// SwiftUIのViewとして `PDFView` を埋め込むには、UIViewRepresentableを実装する必要がある。
struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL // 読み込むPDFファイルのURL
    var displayDirection: PDFDisplayDirection
    
    // MARK: SwiftUI → UIKit: 初回生成時
    // SwiftUIがこのViewを初めて作成するときに呼ばれる。
    // UIKit側のView（PDFView）をここでインスタンス化して設定する。
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url) // URLからPDFを読み込み
        pdfView.autoScales = true // 画面サイズに自動フィット
        
        pdfView.displayDirection = displayDirection
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysAsBook = false
        
        return pdfView
    }
    
    // MARK: SwiftUI → UIKit: 更新時
    // SwiftUIの状態が更新されたとき（＝Viewの再描画が必要なとき）に呼ばれる。
    // ここではURLや設定が変わらないため、何も処理する必要がない。
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // 通常ここでは、SwiftUI側の状態変化をUIKit側に反映させる処理を書く。
        // 例: ページ番号、ズームレベル、アノテーションの更新など。
        // 今回は静的表示のみのため空のままでOK。
    }
}
