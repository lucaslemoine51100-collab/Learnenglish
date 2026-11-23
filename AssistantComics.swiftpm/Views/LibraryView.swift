import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Écran d'accueil : la liste des comics PDF importés.
struct LibraryView: View {
    @EnvironmentObject private var library: ComicLibrary
    @State private var isImporting = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            Group {
                if library.comics.isEmpty {
                    ContentUnavailableView {
                        Label("Aucun comic", systemImage: "books.vertical")
                    } description: {
                        Text("Importez un comic au format PDF depuis l'app Fichiers. Il est copié dans l'app et ne quitte pas l'iPad.")
                    } actions: {
                        Button("Importer un PDF") { isImporting = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(library.comics) { comic in
                            NavigationLink(value: comic) {
                                ComicRow(comic: comic, lastPage: library.lastPage(for: comic))
                            }
                        }
                        .onDelete { library.delete(at: $0) }
                    }
                }
            }
            .navigationTitle("Mes comics")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label("Historique", systemImage: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Label("Importer un PDF", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: ComicFile.self) { comic in
                ReaderView(comic: comic, startPage: library.lastPage(for: comic))
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    importError = library.importFiles(urls)
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .alert("Import impossible",
                   isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
        }
    }
}

private struct ComicRow: View {
    let comic: ComicFile
    let lastPage: Int
    @State private var thumbnail: UIImage?
    @State private var pageCount = 0

    init(comic: ComicFile, lastPage: Int) {
        self.comic = comic
        self.lastPage = lastPage
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "book.closed")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 48, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(comic.name)
                    .font(.headline)
                    .lineLimit(2)
                if pageCount > 0 {
                    Text("\(pageCount) pages · reprise page \(min(lastPage + 1, pageCount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: comic.url) {
            let url = comic.url
            let result = await Task.detached(priority: .utility) { () -> (UIImage?, Int) in
                guard let document = PDFDocument(url: url) else { return (nil, 0) }
                let image = document.page(at: 0)?.thumbnail(of: CGSize(width: 96, height: 144), for: .cropBox)
                return (image, document.pageCount)
            }.value
            thumbnail = result.0
            pageCount = result.1
        }
    }
}
