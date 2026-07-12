import SwiftUI

struct PhotoOcrEditView: View {
    @Binding var ocrText: String
    let thumbnailURL: URL?
    let onClear: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: InsightSpacing.sm) {
            if let thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(InsightColors.surfaceElevated)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(InsightColors.textTertiary)
                            }
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: InsightSpacing.xxs) {
                HStack {
                    Text("Extracted text")
                        .font(InsightTypography.micro())
                        .foregroundStyle(InsightColors.accent)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Spacer()

                    Button("Remove", action: onClear)
                        .font(InsightTypography.micro())
                        .foregroundStyle(InsightColors.textSecondary)
                }

                TextField("Edit OCR text before sending…", text: $ocrText, axis: .vertical)
                    .font(InsightTypography.caption())
                    .foregroundStyle(InsightColors.textPrimary)
                    .lineLimit(2...6)
            }
        }
        .padding(InsightSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: InsightSpacing.cardRadius, style: .continuous)
                .fill(InsightColors.accentSoft)
                .overlay {
                    RoundedRectangle(cornerRadius: InsightSpacing.cardRadius, style: .continuous)
                        .strokeBorder(InsightColors.accent.opacity(0.25), lineWidth: 1)
                }
        }
    }
}

#Preview {
    PhotoOcrEditView(
        ocrText: .constant("YAMAHA F150\nWARNING: HOT SURFACE"),
        thumbnailURL: nil,
        onClear: {}
    )
    .padding()
    .background(InsightBackground())
    .preferredColorScheme(.dark)
}
