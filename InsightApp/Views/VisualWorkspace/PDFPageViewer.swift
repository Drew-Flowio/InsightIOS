import PDFKit
import SwiftUI

struct PDFPageViewer: UIViewRepresentable {
    let pdfURL: URL
    let pageIndex: Int

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.backgroundColor = .clear
        pdfView.usePageViewController(true, withViewOptions: nil)
        context.coordinator.configure(pdfView: pdfView, pdfURL: pdfURL, pageIndex: pageIndex)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.configure(pdfView: pdfView, pdfURL: pdfURL, pageIndex: pageIndex)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var loadedURL: URL?
        private var loadedPageIndex: Int?

        func configure(pdfView: PDFView, pdfURL: URL, pageIndex: Int) {
            if loadedURL != pdfURL {
                loadedURL = pdfURL
                loadedPageIndex = nil
                pdfView.document = PDFDocument(url: pdfURL)
            }
            guard loadedPageIndex != pageIndex,
                  let document = pdfView.document,
                  pageIndex >= 0,
                  pageIndex < document.pageCount,
                  let page = document.page(at: pageIndex) else { return }
            loadedPageIndex = pageIndex
            pdfView.go(to: page)
        }
    }
}
