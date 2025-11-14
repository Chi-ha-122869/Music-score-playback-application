import SwiftUI
//ImportViewの読み込み、保存のところのトースト表示
//OtherViewの共有のところのトースト表示に使われる
struct ToastView: View {
    let message: String
    
    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .padding(.vertical, 30)
                .padding(.horizontal, 40)
                .background(
                    LinearGradient(colors: [Color.appAccent, Color.appOrange.opacity(0.8)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.8), lineWidth: 3)
                )
                .shadow(color: .white.opacity(0.4), radius: 10, x: 0, y: 4)
                .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 6)
                .transition(.scale.combined(with: .opacity))
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
