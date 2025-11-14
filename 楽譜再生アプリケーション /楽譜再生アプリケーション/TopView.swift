import SwiftUI

// MARK: - アプリ起動時に最初に表示されるトップ画面
// 楽譜の読み込み・ライブラリ・その他のメニューへ遷移するハブ的役割を持つ。
struct TopView: View {
    // 各種アニメーション用の状態変数
    @State private var showContent = false      // 全体のフェードイン制御
    @State private var animateIcon = false      // アイコンのアニメーション制御
    @State private var animateTitle = false     // タイトルのアニメーション制御
    
    // ScoreStoreをこのViewで生成し、.environmentObjectとしてアプリ全体に共有
    // → ImportViewやSheetListViewから同じデータ（楽譜情報）を参照できるようにする
    @EnvironmentObject var scoreStore: ScoreStore
    
    var body: some View {
        ZStack {
            // MARK: - 背景グラデーション
            // アプリ全体のテーマカラーであるオレンジ〜ブルーのグラデーションを使用
            LinearGradient(
                gradient: Gradient(colors: [.appOrange, .appDeepBlue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea() // 端末の端まで背景を拡張
            .opacity(showContent ? 1 : 0.0) // 表示アニメーション
            .animation(.easeInOut(duration: 1.2), value: showContent)
            
            ScrollView{
                VStack(spacing: 40) {
                    Spacer().frame(height: 7)

                    // MARK: - アプリのメインアイコン
                    // アニメーション付きで登場するロゴ画像
                    Image("Image")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(animateIcon ? 0 : -15)) // 回転アニメーション
                        .opacity(animateIcon ? 1 : 0) // フェードイン
                        .scaleEffect(animateIcon ? 1 : 0.8) // 拡大縮小アニメーション
                        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                        .animation(
                            .spring(response: 1.2, dampingFraction: 0.6).delay(0.3),
                            value: animateIcon
                        )
                    
                    // MARK: - タイトルテキスト
                    // 「楽譜再生アプリケーション」のメインタイトル表示
                    Text("楽譜再生\nアプリケーション")
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
                        .lineLimit(nil)
                        .minimumScaleFactor(0.5) // 横幅が足りない場合は縮小して表示
                        .opacity(animateTitle ? 1 : 0)
                        .scaleEffect(animateTitle ? 1 : 0.9)
                    // タイトルのフェード＆拡大アニメーション
                        .animation(.easeOut(duration: 1.2).delay(0.6), value: animateTitle)
                    
                    // MARK: - メインメニューのボタン群
                    VStack(spacing: 25) {
                        
                        // MARK: 読み込みボタン
                        // ImportViewへ遷移し、PDFとMP3を読み込む画面を表示
                        NavigationLink(destination: ImportView().environmentObject(scoreStore)) {
                            TopButton(title: "読み込み", subtitle: "PDF、MP3を読み込む")
                        }
                        
                        // MARK: 楽譜ライブラリボタン
                        // SheetListViewへ遷移し、保存された楽譜の一覧を表示
                        // 同じscoreStoreを共有しているため、ImportViewで追加した楽譜がここに反映される
                        NavigationLink(destination: SheetListView().environmentObject(scoreStore)) {
                            TopButton(title: "楽譜ライブラリ", subtitle: "読み込んだ楽譜の一覧")
                        }
                        
                        // MARK: その他ボタン
                        // MuseScoreなどの外部ソフトの操作説明を表示する情報画面
                        NavigationLink(destination: OtherView().environmentObject(scoreStore)) {
                            TopButton(
                                title: "その他",
                                subtitle: "データの共有・取り込み\nMuseScoreのインストール\nPDF・MP3エクスポート方法"
                            )
                        }
                    }
                    // ボタン群のフェードイン
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeInOut(duration: 1).delay(1.0), value: showContent)
                    .padding(.bottom,30)
                }
                .padding(.horizontal, 30)
            }
        }
        // MARK: - onAppear（画面表示時にアニメーション開始）
        .onAppear {
            showContent = true      // 背景とボタン群の表示開始
            animateIcon = true      // アイコンアニメーション開始
            animateTitle = true     // タイトルアニメーション開始
        }
    }
}

// MARK: - カスタムボタン（TopButton）
// すべてのトップメニューに共通するデザインを再利用するためのコンポーネント
struct TopButton: View {
    var title: String       // ボタンのメインタイトル
    var subtitle: String    // ボタンの説明文
    
    var body: some View {
        VStack(spacing: 6) {
            // メインタイトル
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .multilineTextAlignment(.center)
            
            // サブタイトル
            Text(subtitle)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true) // 複数行対応
        }
        .foregroundColor(.appAccent)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            // ボタン背景（深いブルーのグラデーション）
            LinearGradient(
                colors: [.appDeepBlue, .appDeepBlue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 6, x: 4, y: 4)
        .overlay(
            // 半透明の白枠を重ねることで立体感を演出
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 10)
    }
}
