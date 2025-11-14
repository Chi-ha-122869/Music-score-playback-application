import Foundation

// MARK: 個別のMP3パート情報
/// 1つの楽譜に対する「パート演奏音源（例：Flute.mp3、Violin.mp3）」を表す構造体。
/// スコア内で複数のパートを管理できるようにしている。
struct Mp3Part: Identifiable, Hashable, Codable {
    let id: UUID            // 一意の識別子（SwiftUIのListなどで使う）
    let partName: String    // パート名（例：「ソプラノ」「アルト」など）
    let mp3URL: URL         // 音声ファイル（MP3）の保存先URL
}


// MARK: 個別のPDFパート情報
/// 各パートの「譜面PDFファイル（例：Sopurano.pdf、Piano.pdf）」を表す構造体。
/// MP3と同様に、1つの楽譜に複数のパート譜を対応付けられる。
struct PdfPart: Identifiable, Hashable, Codable {
    let id: UUID            // 一意の識別子
    let partName: String    // パート名（例：「Sopurano」「Piano」など）
    let pdfURL: URL         // 譜面PDFファイルのURL
}


// MARK: 楽譜全体データモデル
/// アプリ内で扱う「1曲分のデータ」をまとめた構造体。
/// PDFやMP3などの複数ファイルをまとめて管理する。
struct ScoreModel: Identifiable, Codable, Hashable {
    let id: UUID                // 楽譜ごとのユニークなID
    let name: String            // 楽譜のタイトル（例：「情熱大陸」など）
    let pdfParts: [PdfPart]     // 各パートの譜面データ（PDF）
    let mp3Parts: [Mp3Part]     // 各パートの演奏音源（MP3）
    let fullMp3URL: URL?        // 全体演奏（全パートミックス）の音源ファイル
    var lastOpened: Date?       // 最後に開かれた日時（ライブラリの並び替えなどに利用可能）
    
    
    // MARK: JSON保存用の軽量コピー（ファイル名のみ保持）
    /// ZIPエクスポートなどで使用。
    /// URLを直接保存せず、「ファイル名」だけを保持する軽量構造体に変換する。
    /// （他の端末に取り込んでもファイルを再構築できるようにするため）
    func fileNameBasedCopy() -> ScoreModelFileName {
        // MP3パートを「ファイル名のみの構造体」に変換
        let mp3PartsFileName = mp3Parts.map {
            Mp3PartFileName(
                id: $0.id,
                partName: $0.partName,
                fileName: $0.mp3URL.lastPathComponent // URL → ファイル名だけ抽出
            )
        }
        
        // PDFパートを同様に変換
        let pdfPartsFileName = pdfParts.map {
            PdfPartFileName(
                id: $0.id,
                partName: $0.partName,
                fileName: $0.pdfURL.lastPathComponent
            )
        }
        
        // 軽量モデルを生成して返す
        return ScoreModelFileName(
            id: id,
            name: name,
            pdfParts: pdfPartsFileName,
            mp3Parts: mp3PartsFileName,
            fullMp3FileName: fullMp3URL?.lastPathComponent, // nilの場合も考慮
            lastOpened: lastOpened
        )
    }
}


// MARK: 軽量モデル群（ZIP内JSONで使用）

/// MP3パートをJSONに保存するための簡易構造体。
/// 実ファイルではなく、ファイル名だけを保持する。
struct Mp3PartFileName: Identifiable, Codable {
    let id: UUID
    let partName: String
    let fileName: String // 実際のファイルパスは端末ごとに異なるため、ファイル名のみ
}

/// PDFパートをJSONに保存するための簡易構造体。
struct PdfPartFileName: Identifiable, Codable {
    let id: UUID
    let partName: String
    let fileName: String
}


// MARK: 軽量スコアモデル（ZIP保存・共有用）
/// ZIPエクスポートで `score.json` に保存される構造体。
/// 各ファイルのファイル名を保持し、取り込み時に `ScoreModel` に再変換する。
struct ScoreModelFileName: Identifiable, Codable {
    let id: UUID
    let name: String
    let pdfParts: [PdfPartFileName]
    let mp3Parts: [Mp3PartFileName]
    let fullMp3FileName: String? // 全体MP3のファイル名（ない場合はnil）
    let lastOpened: Date?
    
    
    // MARK: ファイル名ベースのデータから、実際のファイルパスを復元
    /// ZIP取り込み後に実際のアプリ内ファイルパスへ変換する。
    /// DocumentsディレクトリをベースにURLを組み立て直す。
    func toScoreModel() -> ScoreModel {
        // アプリのDocumentsフォルダのURLを取得
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // 各PDFパートをURL付きモデルに変換
        let pdfPartsModel = pdfParts.map {
            PdfPart(
                id: $0.id,
                partName: $0.partName,
                pdfURL: docs.appendingPathComponent($0.fileName)
            )
        }
        
        // 各MP3パートを同様に変換
        let mp3PartsModel = mp3Parts.map {
            Mp3Part(
                id: $0.id,
                partName: $0.partName,
                mp3URL: docs.appendingPathComponent($0.fileName)
            )
        }
        
        // 全体演奏MP3のURLを復元（ファイル名がnilの場合はnilのまま）
        let fullURL = fullMp3FileName != nil
        ? docs.appendingPathComponent(fullMp3FileName!)
        : nil
        
        // 完全なScoreModelを再構築して返す
        return ScoreModel(
            id: id,
            name: name,
            pdfParts: pdfPartsModel,
            mp3Parts: mp3PartsModel,
            fullMp3URL: fullURL,
            lastOpened: lastOpened
        )
    }
}
