import SwiftUI
import PDFKit

struct SanctionLetterPreviewView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // PDF View
                PDFKitRepresentedView(url: url)
                    .edgesIgnoringSafeArea(.all)
                
                // Divider line
                Divider()
                
                // Download button below the sanction letter
                VStack {
                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        showShareSheet = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.body.weight(.bold))
                            Text("Download Sanction Letter")
                                .font(.body.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#2D8B4E"))
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Color.white)
            }
            .navigationTitle("Sanction Letter")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [url])
        }
    }
}

struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
    }
}
