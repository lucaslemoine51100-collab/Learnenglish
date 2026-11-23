import SwiftUI

/// Lecteur : le PDF occupe tout l'écran, l'assistant flotte au-dessus.
struct ReaderView: View {
    @EnvironmentObject private var library: ComicLibrary
    @EnvironmentObject private var history: HistoryStore
    @StateObject private var model: ReaderModel
    @State private var panelCollapsed = false

    init(comic: ComicFile, startPage: Int) {
        _model = StateObject(wrappedValue: ReaderModel(comic: comic, startPage: startPage))
    }

    var body: some View {
        Group {
            if let document = model.document, model.pageCount > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        PDFKitView(document: document,
                                   pageIndex: $model.pageIndex,
                                   highlights: model.highlights) { page, point in
                            model.handleTap(pageIndex: page, point: point)
                        }
                        FloatingPanel(containerSize: geometry.size, isCollapsed: $panelCollapsed) {
                            AssistantPanel(model: model)
                        }
                    }
                }
            } else {
                ContentUnavailableView("PDF illisible",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text("Ce fichier n'a pas pu être ouvert."))
            }
        }
        .navigationTitle(model.comic.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    model.goToPage(model.pageIndex - 1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(model.pageIndex == 0)
                .accessibilityLabel("Page précédente")

                Text("\(model.pageIndex + 1) / \(model.pageCount)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Button {
                    model.goToPage(model.pageIndex + 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(model.pageIndex >= model.pageCount - 1)
                .accessibilityLabel("Page suivante")
            }
        }
        .modifier(TranslationRunner(model: model))
        .onAppear { model.history = history }
        .onChange(of: model.pageIndex) { _, newValue in
            model.pageDidChange()
            library.setLastPage(newValue, for: model.comic)
        }
    }
}
