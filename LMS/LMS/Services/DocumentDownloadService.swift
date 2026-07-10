import Foundation
import Supabase

enum DownloadError: LocalizedError {
    case invalidPath
    case downloadFailed
    case fileSystemError
    
    var errorDescription: String? {
        switch self {
        case .invalidPath: return "Invalid document path."
        case .downloadFailed: return "Failed to download document."
        case .fileSystemError: return "File system error occurred."
        }
    }
}

@MainActor
class DocumentDownloadService {
    static let shared = DocumentDownloadService()
    private init() {}
    
    func downloadDocument(storagePath: String, fileName: String) async throws -> URL {
        let bucket = SupabaseManager.shared.client.storage.from("documents")
        
        guard !storagePath.isEmpty else { throw DownloadError.invalidPath }
        
        let data = try await bucket.download(path: storagePath)
        
        let safeName = fileName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: " ", with: "_")
        let nameWithExt = safeName.contains(".") ? safeName : "\(safeName).pdf"
        
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent(nameWithExt)
        
        do {
            try data.write(to: localURL, options: .atomic)
            return localURL
        } catch {
            throw DownloadError.fileSystemError
        }
    }
}
