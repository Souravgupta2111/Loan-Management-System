import SwiftUI
import PhotosUI

/// Document Upload View for KYC
struct DocumentUploadView: View {
    let title: String
    let subtitle: String
    @Binding var documentData: Data?
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isLoading = false
    @State private var validationError: String?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.cardTitle)
                    .foregroundColor(.textPrimary)
                Text(subtitle)
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if documentData != nil {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 48, height: 48)
                        .foregroundColor(.accentGreen)
                    Text("Document Selected")
                        .font(.bodyLarge)
                        .foregroundColor(.textPrimary)
                    PillButton(title: "Replace", style: .outline) {
                        documentData = nil
                        selectedItem = nil
                    }
                }
                .padding(Spacing.xl)
            } else {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "doc.viewfinder")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .foregroundColor(.textTertiary)

                    if isLoading {
                        ProgressView()
                            .tint(.accentGreen)
                        Text("Loading...")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                    } else {
                        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                            HStack {
                                Image(systemName: "paperclip")
                                Text("Select File")
                            }
                            .font(.bodyLarge)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(Color.accentGreen)
                            .foregroundColor(.appBackground)
                            .clipShape(Capsule())
                        }
                        .onChange(of: selectedItem) { newItem in
                            guard let newItem = newItem else { return }
                            isLoading = true
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self) {
                                    if data.count > 5 * 1024 * 1024 {
                                        validationError = "File exceeds the 5 MB limit."
                                        documentData = nil
                                    } else {
                                        validationError = nil
                                        documentData = data
                                    }
                                }
                                isLoading = false
                            }
                        }

                        Text("Supported formats: PDF, JPG, PNG (Max 5MB)")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)

                        if let validationError {
                            Text(validationError)
                                .font(.caption2)
                                .foregroundColor(.accentRed)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.xl)
                .background(Color.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Corner.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: Corner.lg)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .foregroundColor(.border)
                )
            }
        }
        .padding(Spacing.xl)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
}
