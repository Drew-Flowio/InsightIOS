import SwiftUI

struct PhotoActionButtonsView: View {
    let isDisabled: Bool
    let onTakePhoto: () -> Void
    let onSelectPhoto: () -> Void

    var body: some View {
        HStack(spacing: InsightSpacing.xs) {
            Button(action: onTakePhoto) {
                Label("Camera", systemImage: "camera.fill")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(InsightIconButtonStyle(tint: InsightColors.textPrimary))
            .disabled(isDisabled)
            .accessibilityLabel("Take photo")

            Button(action: onSelectPhoto) {
                Label("Photos", systemImage: "photo.on.rectangle.angled")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(InsightIconButtonStyle(tint: InsightColors.textPrimary))
            .disabled(isDisabled)
            .accessibilityLabel("Select photo")
        }
    }
}

#Preview {
    PhotoActionButtonsView(isDisabled: false, onTakePhoto: {}, onSelectPhoto: {})
        .padding()
        .background(InsightBackground())
        .preferredColorScheme(.dark)
}
