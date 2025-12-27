import SwiftUI
import AVFoundation

struct PlayerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var scoreStore: ScoreStore
    let score: ScoreModel // 表示・再生対象の楽譜
    
    // MARK: - パート別ON/OFF管理
    @State private var partSwitches: [UUID: Bool] = [:]  // パートIDごとのON/OFF状態
    @State private var audioPlayers: [UUID: AVAudioPlayer] = [:] // パート別AVAudioPlayer
    @State private var fullPlayer: AVAudioPlayer? // 全体MP3用AVAudioPlayer
    @State private var selectedPDFPartID: UUID? = nil
    @State private var selectedPdfIndex = 0
    @State private var isPlaying = false   // 再生中フラグ
    @State private var isLooping = false   // ループ再生中フラグ
    @State private var wasPlayingBeforeSeek: Bool = false  // スライダー操作前の状態保存
    
    @State private var playbackRate: Float = 1.0 // 再生速度（1.0倍が通常）
    @State private var wasPlayingBeforeSpeedAdjust: Bool = false

    
    @State private var currentTime: Double = 0.0 // 現在再生時間
    @State private var duration: Double = 1.0    // 全体再生時間（初期値1秒）
    @State private var timer: Timer?             // 進行度更新用タイマー
    
    @State private var loopStart: Double = 0.0   // ループ開始位置
    @State private var loopEnd: Double = 0.0     // ループ終了位置
    
    
    @State private var isControlCollapsed = false //コントロール部分収納

    
    //画面スリープ制御
    func setIdleTimeerDisabled(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
    
    // MARK: - 初期設定（プレイヤー準備）
    func setupPlayers() {
        // パートON/OFF初期化
        if partSwitches.isEmpty {
            for part in score.mp3Parts { partSwitches[part.id] = true }
        }
        
        // 全体MP3プレイヤー準備
        if fullPlayer == nil, let url = score.fullMp3URL {
            fullPlayer = try? AVAudioPlayer(contentsOf: url)
            fullPlayer?.prepareToPlay()
            duration = fullPlayer?.duration ?? duration
        }
        
        // パートごとのプレイヤー準備
        for part in score.mp3Parts {
            if audioPlayers[part.id] == nil {
                let player = try? AVAudioPlayer(contentsOf: part.mp3URL)
                player?.prepareToPlay()
                audioPlayers[part.id] = player
                if let d = player?.duration, d > duration { duration = d } // 全体時間を更新
            }
        }
        
        // ループ終了位置を全体長さに設定
        if loopEnd == 0.0 { loopEnd = duration }
    }
    
    // MARK: - UI
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(gradient: Gradient(colors: [.appOrange, .appDeepBlue]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            .ignoresSafeArea()
            
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        // PDF表示部分
                        pdfSection(geometry: geometry)
                        
                        // コントロール部分
                        controlSection(geometry: geometry)
                            .offset(y: isControlCollapsed ? controlHideOffset(geometry) : 0)
                            .animation(.easeInOut(duration: 0.35), value: isControlCollapsed)
                            .allowsHitTesting(!isControlCollapsed) // ← 完全に触れなくする
                    }
                    
                    // 収納中に表示される「戻すボタン」
                    if isControlCollapsed {
                        restoreButton(geometry: geometry)
                    }
                }
            }
        }
        .onAppear { setupPlayers()
            if let index = scoreStore.scores.firstIndex(where: { $0.id == score.id }) {
                scoreStore.scores[index].lastOpened = Date()
            }
        }
        .onDisappear { stopAllPlayers()
            setIdleTimeerDisabled(false)//画面スリープ復帰
        }
        .navigationTitle(score.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.appDeepBlue.opacity(0.5), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }


    //MARK: PDF表示部分
    @ViewBuilder
    private func pdfSection(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            // PDFビュー（選択された譜面を表示、安全版）
            if !score.pdfParts.isEmpty {
                PDFAnnotatableView(
                    url: score.pdfParts[selectedPdfIndex].pdfURL,
                    displayDirection: .horizontal
                )
                .id(score.pdfParts[selectedPdfIndex].id)
                .frame(
                    height: geometry.size.height *
                    (isControlCollapsed ? 0.92 : 0.61)
                )
                .animation(.easeInOut(duration: 0.35), value: isControlCollapsed)
                .padding(.top, 1)
            } else {
                Text("PDFが登録されていません")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(height: geometry.size.height * 2 / 3)
            }
            
            // 左上ドロップダウン（カスタム色付き）
            if score.pdfParts.count > 1 {
                Menu {
                    // 中の選択肢（PDFパート名一覧）
                    ForEach(0..<score.pdfParts.count, id: \.self) { index in
                        Button {
                            selectedPdfIndex = index
                        } label: {
                            Text(score.pdfParts[index].partName)
                                .foregroundColor(.white) // メニュー内の文字は白
                        }
                    }
                } label: {
                    // 表示中の部分（ラベル）
                    HStack(spacing: 6) {
                        Text(score.pdfParts[selectedPdfIndex].partName)
                            .foregroundColor(.appAccent)
                            .font(.system(size: 18, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .foregroundColor(.appAccent)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.vertical, 9)
                    .padding(.horizontal, 8)
                    .background(Color.appDeepBlue) // ← 紺色
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.appAccent.opacity(0.8), lineWidth: 1.2)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 2)
                }
                .padding(.leading, 12)
                .padding(.top, 5)
            }
        }
    }

    private func controlHideOffset(_ geometry: GeometryProxy) -> CGFloat {
        geometry.size.height * 0.45
    }

    //MARK: コントロール部分
    @ViewBuilder
    private func controlSection(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .topTrailing){
            
            
            ScrollView {
                VStack(spacing: 10) {
                    
                    // 再生位置バー（上段）
                    playbackSlider()
                        .padding(.top, 25)
                    
                    //  中段：左に再生・ループボタン、右に速度バーとループ範囲
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 10) {
                            // 再生ボタン
                            CustomPlayButton(
                                title: isPlaying ? "停止" : "再生",
                                icon: isPlaying ? "stop.fill" : "play.fill",
                                color: isPlaying ? .gray : .appAccent
                            ) {
                                if isPlaying {
                                    setIdleTimeerDisabled(false)
                                    stopAllPlayers()
                                } else {
                                    isLooping = false
                                    startPlayback()
                                }
                            }
                            .padding(.bottom, 45)
                            // ループボタン（再生ボタンの下）
                            CustomPlayButton(
                                title: "ループ",
                                icon: "repeat.circle.fill",
                                color: .appAccent
                            ) {
                                if isLooping {
                                    startLoopPlayback(forceSeek: true)
                                } else {
                                    startLoopPlayback(forceSeek: false)
                                }
                            }
                        }
                        .frame(width: geometry.size.width * 0.28)
                        .padding(.top, 17)
                        
                        // 右側：速度バー＋ループ範囲設定
                        VStack(alignment: .leading, spacing: 18) {
                            playbackSpeedBar()
                            loopSettings()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Divider().background(.white.opacity(0.3))
                    partSwitchSection() // パートON/OFFはそのまま
                }
                .padding()
                .frame(minHeight: geometry.size.height / 3)
            }
            //収納ボタン
            Button {
                withAnimation {
                    isControlCollapsed = true
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.down")
                }
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color.green.opacity(0.45))
                        .shadow(radius: 2)
                )
            }
            .padding(5)
        }
        .background(Color.appDeepBlue.opacity(0.7))
    }
    
    //戻すボタン
    @ViewBuilder
    private func restoreButton(geometry: GeometryProxy) -> some View {
        VStack {
            HStack {
                Spacer()
                
                Button {
                    withAnimation {
                        isControlCollapsed = false
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.up")
                    }
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.green.opacity(0.45))
                            .shadow(radius: 2)
                    )
                }
                .padding(10)
            }
        }
    }

    //MARK: 再生スライダー
    @ViewBuilder
    private func playbackSlider() -> some View {
        VStack {
            Slider(value: $currentTime, in: 0...duration, onEditingChanged: { editing in
                if editing {
                    // スライダー操作を開始したら、今の再生状態を記録して一時停止
                    wasPlayingBeforeSeek = isPlaying
                    if isPlaying {
                        setIdleTimeerDisabled(false)
                        stopAllPlayers()
                    }
                } else {
                    // 操作が終わったら再生位置を更新
                    seekAllPlayers(to: currentTime)
                    
                    // 「操作前に再生していた場合のみ」再開する
                    if wasPlayingBeforeSeek {
                        if isLooping {
                            startLoopPlayback(forceSeek: true)
                        } else {
                            startPlayback()
                        }
                    }
                }
            })
            .tint(.appAccent)
            
            HStack {
                Text(formatTime(currentTime))
                Spacer()
                Text(formatTime(duration))
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
        }
    }
    // MARK: - 再生速度バー
    @ViewBuilder
    private func playbackSpeedBar() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("再生速度: \(String(format: "%.1fx", playbackRate))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            // スライダー本体：
            // - スライダー操作開始(onEditingChanged: true)で一時停止（再生中だったかを保存）
            // - 操作終了(onEditingChanged: false)で速度を適用 -> 必要に応じて再生を再開
            Slider(
                value: Binding(
                    get: { Double(playbackRate) },
                    set: { newValue in
                        // 移動中は値だけ更新（再生は再開時に適用）
                        playbackRate = Float(newValue)
                    }
                ),
                in: 0.5...1.5,
                step: 0.1,
                onEditingChanged: { editing in
                    if editing {
                        // スライダー操作開始：再生中なら停止して状態を保存
                        wasPlayingBeforeSpeedAdjust = isPlaying
                        if isPlaying {
                            setIdleTimeerDisabled(false)
                            stopAllPlayers()
                        }
                    } else {
                        // 操作終了：速度反映、そして元の再生状態に応じて再開
                        updatePlaybackRate() // 速度値をプレイヤーに設定
                        
                        // 再開（操作前に再生していた場合のみ）
                        if wasPlayingBeforeSpeedAdjust {
                            if isLooping {
                                // ループ中だったならループ再生を再開（位置は既に currentTime）
                                startLoopPlayback(forceSeek: true)
                            } else {
                                // 通常再生を再開
                                startPlayback()
                            }
                        }
                    }
                }
            )
            .tint(.appAccent)
        }
    }

    
    // MARK: - 再生速度更新処理
    private func updatePlaybackRate() {
        fullPlayer?.enableRate = true
        fullPlayer?.rate = playbackRate
        for p in audioPlayers.values {
            p.enableRate = true
            p.rate = playbackRate
        }
    }
    //MARK: ループ範囲設定
    @ViewBuilder
    private func loopSettings() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("ループ範囲設定")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            LoopSlider(label: "開始", time: $loopStart, range: 0...duration, color: .green)
            LoopSlider(label: "終了", time: $loopEnd, range: loopStart...duration, color: .red)
        }
        .padding(.horizontal, 10)
    }


    //MARK: パートON/OFF切り替え
    @ViewBuilder
    private func partSwitchSection() -> some View {
        VStack(spacing: 15) {
            // タイトル
            Text("パートON/OFF（ONのみ再生）")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            //全てON / OFFボタン（タイトルの下に配置）
            HStack(spacing: 25) {
                Button {
                    // 全てON
                    for id in score.mp3Parts.map({ $0.id }) {
                        partSwitches[id] = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("全てON")
                    }
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.8))
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 2)
                    )
                }
                
                Button {
                    // 全てOFF
                    for id in score.mp3Parts.map({ $0.id }) {
                        partSwitches[id] = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("全てOFF")
                    }
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.8))
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 2)
                    )
                }
            }
            .padding(.horizontal, 10)
            
            //各パートトグル一覧
            ForEach(score.mp3Parts) { part in
                PartToggleView(
                    part: part,
                    isOn: Binding(
                        get: { partSwitches[part.id] ?? true },
                        set: { partSwitches[part.id] = $0 }
                    )
                )
            }
        }
        .padding(.horizontal, 10)
    }



    // MARK: - 再生制御
    
    func startPlayback() {
        
        stopAllPlayers() // 全停止
        setupAudioSession()
        
        setIdleTimeerDisabled(true)  //再生開始でスリープ無効化
        
        let activeParts = score.mp3Parts.filter { partSwitches[$0.id] ?? false }
        //全OFFなら何もせず return
        if activeParts.isEmpty {
            print("全てのパートがOFFのためループ再生を開始しません。")
            return
        }
        
        if activeParts.count == score.mp3Parts.count, let fp = fullPlayer {
            // 全パートONなら全体MP3で再生
            fp.currentTime = currentTime
            fp.play()
        } else {
            // 個別パート再生
            for part in activeParts {
                audioPlayers[part.id]?.currentTime = currentTime
                audioPlayers[part.id]?.play()
            }
        }
        isPlaying = true
        startProgressTimer()
    }
    
    func startLoopPlayback(forceSeek: Bool) {
        //有効なパートを確認
        let activeParts = score.mp3Parts.filter { partSwitches[$0.id] ?? false }
        //全OFFなら何もせず return
        if activeParts.isEmpty {
            print("全てのパートがOFFのためループ再生を開始しません。")
            return
        }
        //通常処理
        if !isLooping || forceSeek {
            stopAllPlayers()
            setupAudioSession()
            seekAllPlayers(to: loopStart)
            setIdleTimeerDisabled(true)
            isLooping = true
            startPlayback()
        } else {
            stopLoopPlayback()
        }
    }

    
    func stopAllPlayers() {
        timer?.invalidate(); timer = nil
        fullPlayer?.stop()
        for p in audioPlayers.values { p.stop() }
        isPlaying = false
    }
    
    func stopLoopPlayback() {
        isLooping = false
        stopAllPlayers()
        setIdleTimeerDisabled(false)
    }
    
    func seekAllPlayers(to time: Double) {
        fullPlayer?.currentTime = time
        for p in audioPlayers.values { p.currentTime = time }
        currentTime = time
    }
    
    func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }
    
    // MARK: - タイマー
    func startProgressTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            var now: Double = 0.0
            if let f = fullPlayer, f.isPlaying { now = f.currentTime }
            else if let any = audioPlayers.values.first(where: { $0.isPlaying }) { now = any.currentTime }
            
            currentTime = now
            
            // ループ再生時
            if isLooping && currentTime >= loopEnd - 0.3 {
                seekAllPlayers(to: loopStart)
                if fullPlayer?.isPlaying == true { fullPlayer?.play() }
                else {
                    for (id, player) in audioPlayers { if partSwitches[id] ?? false { player.play() } }
                }
            }
            
            // 通常再生終了時
            if !isLooping {
                let anyPlaying = fullPlayer?.isPlaying == true || audioPlayers.values.contains(where: { $0.isPlaying })
                if !anyPlaying && currentTime < 0.05 {
                    stopAllPlayers()
                }
            }
        }
    }
    
    // MARK: - 時間表示フォーマット
    func formatTime(_ time: Double) -> String {
        let totalSeconds = Int(time)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

// MARK: - 再利用可能UIコンポーネント

struct CustomPlayButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.headline.bold())
            }
            .foregroundColor(color)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.appDeepBlue.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 2, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(color.opacity(0.8), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LoopSlider: View {
    @State private var formattedTime: String = "00:00"
    let label: String
    @Binding var time: Double
    let range: ClosedRange<Double>
    let color: Color
    
    var body: some View {
        HStack {
            Text("\(label): \(formattedTime)")
                .frame(width: 100, alignment: .leading)
                .font(.subheadline.bold())
                .foregroundColor(color)
            
            Slider(value: $time, in: range)
                .tint(color)
        }
        .onChange(of: time) { formattedTime = formatTime(time) }
        .onAppear { formattedTime = formatTime(time) }
    }
    
    private func formatTime(_ time: Double) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct PartToggleView: View {
    let part: Mp3Part
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(part.partName)
                .font(.body.bold())
                .foregroundColor(isOn ? .white : .white.opacity(0.5))
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.appAccent)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.appDeepBlue)
                .opacity(isOn ? 1.0 : 0.6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isOn ? Color.appAccent : Color.gray.opacity(0.5), lineWidth: 1)
        )
    }
}
