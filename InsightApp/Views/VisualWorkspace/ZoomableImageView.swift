import SwiftUI
import UIKit

struct ZoomableImageView: UIViewRepresentable {
    let imageURL: URL

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tag = 100
        scrollView.addSubview(imageView)

        context.coordinator.loadImage(from: imageURL, into: imageView, scrollView: scrollView)
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = scrollView.viewWithTag(100) as? UIImageView else { return }
        context.coordinator.loadImage(from: imageURL, into: imageView, scrollView: scrollView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        private var loadedURL: URL?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.viewWithTag(100)
        }

        func loadImage(from url: URL, into imageView: UIImageView, scrollView: UIScrollView) {
            guard loadedURL != url else { return }
            loadedURL = url

            if url.isFileURL, let image = UIImage(contentsOfFile: url.path) {
                apply(image: image, to: imageView, scrollView: scrollView)
                return
            }

            Task { @MainActor in
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let image = UIImage(data: data) else { return }
                apply(image: image, to: imageView, scrollView: scrollView)
            }
        }

        private func apply(image: UIImage, to imageView: UIImageView, scrollView: UIScrollView) {
            imageView.image = image
            imageView.frame = CGRect(origin: .zero, size: image.size)
            scrollView.contentSize = image.size
            scrollView.zoomScale = 1
            centerImage(in: scrollView)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
        }

        private func centerImage(in scrollView: UIScrollView) {
            guard let imageView = scrollView.viewWithTag(100) else { return }
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
            imageView.center = CGPoint(
                x: scrollView.contentSize.width * 0.5 + offsetX,
                y: scrollView.contentSize.height * 0.5 + offsetY
            )
        }
    }
}
