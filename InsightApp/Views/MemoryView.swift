import SwiftUI
import InsightStorage

struct MemoryView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                InsightBackground()

                Form {
                    Section {
                        TextField("Your name", text: $viewModel.userProfileName)
                            .textInputAutocapitalization(.words)

                        Picker("Response style", selection: $viewModel.userProfileStyle) {
                            Text("Balanced").tag("balanced")
                            Text("Concise").tag("concise")
                            Text("Detailed").tag("detailed")
                            Text("Technical").tag("technical")
                            Text("Casual").tag("casual")
                        }

                        TextField("General notes (optional)", text: $viewModel.userProfileNotes, axis: .vertical)
                            .lineLimit(2...4)
                    } header: {
                        Text("Profile")
                    } footer: {
                        Text("Profile details stay on this device and shape how Insight answers.")
                    }

                    Section {
                        if viewModel.memoryFacts.isEmpty {
                            Text("No saved memories yet. Say “Remember that …” in chat to add one.")
                                .font(InsightTypography.caption())
                                .foregroundStyle(InsightColors.textSecondary)
                        } else {
                            ForEach(viewModel.memoryFacts) { fact in
                                VStack(alignment: .leading, spacing: InsightSpacing.xxs) {
                                    Text(fact.text)
                                        .font(InsightTypography.body())
                                        .foregroundStyle(InsightColors.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.deleteMemoryFact(id: fact.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Saved memories")
                    } footer: {
                        Text("Only facts you explicitly ask Insight to remember appear here.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        viewModel.saveUserProfile()
                        dismiss()
                    }
                    .foregroundStyle(InsightColors.textPrimary)
                }
            }
            .task {
                await viewModel.loadMemory()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MemoryView(viewModel: ChatViewModel(previewMessages: []))
}
