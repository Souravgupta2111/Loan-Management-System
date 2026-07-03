import SwiftUI
import PhotosUI
import UIKit

/// Document Upload View for KYC & Loan Applications
struct DocumentUploadView: View {
    let title: String
    let subtitle: String
    @Binding var documentData: Data?
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isLoading = false
    @State private var validationError: String?
    @State private var showPreview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let data = documentData {
                // Uploaded State Card
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.accentGreenBg)
                            .frame(width: 44, height: 44)
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.accentGreen)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.accentGreen)
                            Text("Uploaded")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.accentGreen)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentGreenBg)
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 10) {
                        Button {
                            showPreview = true
                        } label: {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.accentGreen)
                                .frame(width: 36, height: 36)
                                .background(Color.accentGreenBg)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            documentData = nil
                            selectedItem = nil
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.accentRed)
                                .frame(width: 36, height: 36)
                                .background(Color.accentRed.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentGreen.opacity(0.25), lineWidth: 1)
                )
            } else {
                // Empty / Upload Input Card
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4]))
                            .foregroundColor(.textTertiary)
                            .frame(width: 44, height: 44)
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 16))
                            .foregroundColor(.textTertiary)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .tint(.accentGreen)
                            .frame(width: 82, height: 34)
                    } else {
                        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.doc")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Upload")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.accentGreen)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .onChange(of: selectedItem) { _, newItem in
                            guard let newItem = newItem else { return }
                            isLoading = true
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self) {
                                    let uploadData = Self.normalizedImageData(from: data) ?? data
                                    if uploadData.count > 2 * 1024 * 1024 {
                                        validationError = "File exceeds the 2 MB limit."
                                        documentData = nil
                                    } else {
                                        validationError = nil
                                        documentData = uploadData
                                    }
                                }
                                isLoading = false
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.border, lineWidth: 1)
                )
            }
            
            if let validationError {
                Text(validationError)
                    .font(.caption2)
                    .foregroundColor(.accentRed)
                    .padding(.top, 6)
                    .padding(.horizontal, 4)
            }
        }
        .sheet(isPresented: $showPreview) {
            NavigationStack {
                VStack {
                    if let data = documentData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(12)
                            .padding(24)
                            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 44))
                                .foregroundColor(.textTertiary)
                            Text("Unable to preview document")
                                .font(.bodyLarge)
                                .foregroundColor(.textPrimary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#E7EFE5"), Color(hex: "#EFF4EA"), Color(hex: "#E7EFE5")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") {
                            showPreview = false
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.accentGreen)
                    }
                }
            }
        }
    }

    private static func normalizedImageData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let maxDimension: CGFloat = 1200
        let longestSide = max(image.size.width, image.size.height)
        let targetSize: CGSize

        if longestSide > maxDimension {
            let scale = maxDimension / longestSide
            targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        } else {
            targetSize = image.size
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resizedImage.jpegData(compressionQuality: 0.55)
    }
}
