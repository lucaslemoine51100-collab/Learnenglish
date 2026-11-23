import Foundation
import Combine

/// Un fichier PDF de la bibliothèque.
struct ComicFile: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

/// Bibliothèque locale : les PDF importés sont copiés dans « Documents/Comics » de l'app.
/// Les fichiers ne quittent jamais l'iPad.
@MainActor
final class ComicLibrary: ObservableObject {
    @Published private(set) var comics: [ComicFile] = []

    let folder: URL
    private let fileManager = FileManager.default

    init() {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = documents.appendingPathComponent("Comics", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let urls = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                         options: [.skipsHiddenFiles])) ?? []
        comics = urls
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .sorted { modificationDate($0) > modificationDate($1) }
            .map { ComicFile(url: $0) }
    }

    /// Copie les fichiers choisis dans la bibliothèque. Retourne un message d'erreur, ou nil si tout s'est bien passé.
    func importFiles(_ urls: [URL]) -> String? {
        var failures: [String] = []
        for url in urls {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            let destination = uniqueDestination(for: url.lastPathComponent)
            do {
                try fileManager.copyItem(at: url, to: destination)
            } catch {
                failures.append("\(url.lastPathComponent) : \(error.localizedDescription)")
            }
        }
        reload()
        return failures.isEmpty ? nil : failures.joined(separator: "\n")
    }

    func delete(at offsets: IndexSet) {
        for index in offsets where comics.indices.contains(index) {
            try? fileManager.removeItem(at: comics[index].url)
        }
        reload()
    }

    func lastPage(for comic: ComicFile) -> Int {
        UserDefaults.standard.integer(forKey: lastPageKey(comic))
    }

    func setLastPage(_ page: Int, for comic: ComicFile) {
        UserDefaults.standard.set(page, forKey: lastPageKey(comic))
    }

    private func lastPageKey(_ comic: ComicFile) -> String {
        "lastPage." + comic.url.lastPathComponent
    }

    private func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func uniqueDestination(for fileName: String) -> URL {
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension.isEmpty ? "pdf" : (fileName as NSString).pathExtension
        var candidate = folder.appendingPathComponent("\(base).\(ext)")
        var counter = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) (\(counter)).\(ext)")
            counter += 1
        }
        return candidate
    }
}
