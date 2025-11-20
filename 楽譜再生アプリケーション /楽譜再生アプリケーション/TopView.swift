import SwiftUI

// MARK: - TopView
// アプリ起動時に表示されるトップ画面
// 楽譜の読み込み・ライブラリ・その他のメニューへ遷移するハブ的役割を持つ
struct TopView: View {
    // 背景、ボタン、アイコン、タイトルのアニメーション制御用状態変数
    @State private var showBackground = false   // 背景グラデーションのフェードイン
    @State private var showButtons = false      // ボタン群のフェードイン
    @State private var animateIcon = false      // アプリアイコンのフェード＆回転
    @State private var animateTitle = false     // タイトルのフェード＆拡大
    
    // ScoreStoreを環境オブジェクトとして受け取る
    // 他の画面（ImportView, SheetListViewなど）と共有
    @EnvironmentObject var scoreStore: ScoreStore
    
    var body: some View {
        ZStack {
            // MARK: - 背景グラデーション
            // アプリ全体のテーマカラー
            LinearGradient(
                colors: [.appOrange, .appDeepBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea() // 画面端まで拡張
            .opacity(showBackground ? 1 : 0) // 表示フェード
            
            // MARK: - コンテンツ
            ScrollView {
                VStack(spacing: 40) {
                    Spacer().frame(height: 7) // 上部余白
                    
                    // MARK: - アプリのメインアイコン
                    // フェードイン + 回転 + 拡大アニメーション
                    Image("Image")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .opacity(animateIcon ? 1 : 0)
                        .scaleEffect(animateIcon ? 1 : 0.8)
                        .rotationEffect(.degrees(animateIcon ? 0 : -15))
                        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                        .animation(.spring(response: 1.2, dampingFraction: 0.6), value: animateIcon)
                    
                    // MARK: - タイトルテキスト
                    // 「楽譜再生アプリケーション」をグラデーション文字で表示
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
                        .opacity(animateTitle ? 1 : 0)
                        .scaleEffect(animateTitle ? 1 : 0.9)
                        .animation(.easeOut(duration: 1.2), value: animateTitle)
                    
                    // MARK: - メインメニューのボタン群
                    VStack(spacing: 25) {
                        // 読み込みボタン → ImportViewへ遷移
                        NavigationLink(destination: ImportView().environmentObject(scoreStore)) {
                            TopButton(title: "読み込み", subtitle: "PDF、MP3を読み込む")
                        }
                        
                        // 楽譜ライブラリボタン → SheetListViewへ遷移
                        NavigationLink(destination: SheetListView().environmentObject(scoreStore)) {
                            TopButton(title: "楽譜ライブラリ", subtitle: "読み込んだ楽譜の一覧")
                        }
                        
                        // その他ボタン → OtherViewへ遷移
                        NavigationLink(destination: OtherView().environmentObject(scoreStore)) {
                            TopButton(
                                title: "その他",
                                subtitle: "データの共有・取り込み\nMuseScoreのインストール\nPDF・MP3エクスポート方法"
                            )
                        }
                    }
                    .opacity(showButtons ? 1 : 0) // ボタン群のフェードイン
                    .offset(y: showButtons ? 0 : 20) // 少し下から上にスライドする演出
                    .animation(.easeInOut(duration: 1.0), value: showButtons)
                    .padding(.bottom, 30) // 下部余白
                }
                .padding(.horizontal, 30)
            }
        }
        .onAppear {
            // 画面表示時の順次アニメーション
            withAnimation(.easeInOut(duration: 1.0)) { showBackground = true } // 背景フェード
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { animateIcon = true } // アイコン
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { animateTitle = true } // タイトル
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showButtons = true } // ボタン群
        }
    }
}

// MARK: - TopButton
// トップ画面の各ボタン共通コンポーネント
struct TopButton: View {
    var title: String    // ボタンのメインタイトル
    var subtitle: String // ボタンの補足説明
    
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
                .fixedSize(horizontal: false, vertical: true) // 複数行対応
        }
        .foregroundColor(.appAccent) // 文字色（アクセントカラー）
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.appDeepBlue, .appDeepBlue.opacity(0.8)], // ボタン背景グラデーション
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20) // 角丸
        .shadow(color: .black.opacity(0.3), radius: 6, x: 4, y: 4) // ドロップシャドウ
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1) // 薄い白枠で立体感
        )
        .padding(.horizontal, 10)
    }
}
