import SwiftUI
import PDFKit
import UIKit

/// Affichage du PDF page par page (glisser pour tourner les pages).
/// Les repères des bulles sont des annotations ajoutées en mémoire : le fichier n'est jamais modifié.
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var pageIndex: Int
    let highlights: [PageHighlight]
    let onTap: (Int, CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(pageIndex: $pageIndex, onTap: onTap)
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.usePageViewController(true, withViewOptions: nil)
        view.autoScales = true
        view.backgroundColor = .black
        if let page = document.page(at: pageIndex) { view.go(to: page) }
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.pageIndex = $pageIndex
        context.coordinator.onTap = onTap
        if let page = document.page(at: pageIndex), view.currentPage != page {
            view.go(to: page)
        }
        context.coordinator.apply(highlights: highlights, pageIndex: pageIndex, in: view)
    }

    static func dismantleUIView(_ view: PDFView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var pageIndex: Binding<Int>
        var onTap: (Int, CGPoint) -> Void

        private weak var view: PDFView?
        private var annotations: [(page: PDFPage, annotation: PDFAnnotation)] = []
        private var appliedHighlights: [PageHighlight] = []
        private var appliedPage = -1

        init(pageIndex: Binding<Int>, onTap: @escaping (Int, CGPoint) -> Void) {
            self.pageIndex = pageIndex
            self.onTap = onTap
        }

        func attach(to view: PDFView) {
            self.view = view
            NotificationCenter.default.addObserver(self, selector: #selector(pageChanged(_:)),
                                                   name: .PDFViewPageChanged, object: view)
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
            tap.delegate = self
            tap.cancelsTouchesInView = false
            view.addGestureRecognizer(tap)
        }

        func detach() {
            NotificationCenter.default.removeObserver(self)
            removeAnnotations()
        }

        @objc private func pageChanged(_ notification: Notification) {
            guard let view, let document = view.document, let page = view.currentPage else { return }
            let index = document.index(for: page)
            if pageIndex.wrappedValue != index {
                DispatchQueue.main.async { self.pageIndex.wrappedValue = index }
            }
        }

        @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
            guard let view, let document = view.document else { return }
            let location = recognizer.location(in: view)
            guard let page = view.page(for: location, nearest: false) else { return }
            let point = view.convert(location, to: page)
            onTap(document.index(for: page), point)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        func apply(highlights: [PageHighlight], pageIndex: Int, in view: PDFView) {
            guard highlights != appliedHighlights || pageIndex != appliedPage else { return }
            removeAnnotations()
            appliedHighlights = highlights
            appliedPage = pageIndex
            guard !highlights.isEmpty, let page = view.document?.page(at: pageIndex) else { return }

            let box = page.bounds(for: .cropBox)
            let unit = max(box.width, box.height) / 100 // 1 % de la page

            for highlight in highlights {
                let tint: UIColor = highlight.selected ? .systemOrange : .systemBlue

                let frame = PDFAnnotation(bounds: highlight.rect.insetBy(dx: -unit * 0.4, dy: -unit * 0.4),
                                          forType: .square, withProperties: nil)
                let border = PDFBorder()
                border.lineWidth = highlight.selected ? unit * 0.45 : unit * 0.2
                frame.border = border
                frame.color = tint.withAlphaComponent(highlight.selected ? 1 : 0.8)
                if highlight.selected { frame.interiorColor = tint.withAlphaComponent(0.12) }
                frame.isReadOnly = true
                page.addAnnotation(frame)
                annotations.append((page: page, annotation: frame))

                let side = unit * 2.6
                let width = side * (highlight.number >= 10 ? 1.5 : 1.1)
                var labelRect = CGRect(x: highlight.rect.minX - width * 0.6, y: highlight.rect.maxY - side * 0.4,
                                       width: width, height: side)
                labelRect.origin.x = min(max(labelRect.minX, box.minX), box.maxX - width)
                labelRect.origin.y = min(max(labelRect.minY, box.minY), box.maxY - side)
                let label = PDFAnnotation(bounds: labelRect, forType: .freeText, withProperties: nil)
                label.contents = "\(highlight.number)"
                label.font = UIFont.systemFont(ofSize: side * 0.72, weight: .heavy)
                label.fontColor = .white
                label.color = tint
                label.alignment = .center
                let labelBorder = PDFBorder()
                labelBorder.lineWidth = 0
                label.border = labelBorder
                label.isReadOnly = true
                page.addAnnotation(label)
                annotations.append((page: page, annotation: label))
            }
        }

        private func removeAnnotations() {
            for item in annotations { item.page.removeAnnotation(item.annotation) }
            annotations.removeAll()
        }
    }
}
