import SwiftUI
import InsightCore

struct AppRootView: View {
    @State private var viewModel = ChatViewModel()

    var body: some View {
        Group {
            if shouldShowFirstRunSetup {
                FirstRunSetupView(viewModel: viewModel)
            } else {
                MainChatView(viewModel: viewModel)
            }
        }
    }

    private var shouldShowFirstRunSetup: Bool {
        !ProductSetupStore.hasCompletedSetup && !viewModel.productSetupFinished && viewModel.bootstrapState != .preview
    }
}

#Preview {
    AppRootView()
}
