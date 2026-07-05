import SwiftUI
import UIKit

struct CameraPickerView: UIViewControllerRepresentable {
    let onImagePicked: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (URL) -> Void
        let onCancel: () -> Void

        init(onImagePicked: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                onCancel()
                return
            }

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("insight-camera-\(UUID().uuidString).jpg")

            if let data = image.jpegData(compressionQuality: 0.88) {
                try? data.write(to: url)
                onImagePicked(url)
            } else {
                onCancel()
            }
        }
    }
}
