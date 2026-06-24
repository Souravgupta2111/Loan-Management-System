import SwiftUI

/// Form Input Field (design.md §5.7)
struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var error: String? = nil
    var keyboardType: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label)
                .font(.label)
                .foregroundColor(.textSecondary)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                }
            }
            .font(.bodyLarge)
            .foregroundColor(.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Corner.md))
            .overlay(
                RoundedRectangle(cornerRadius: Corner.md)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .focused($isFocused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            if let error = error, !error.isEmpty {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.accentRed)
            }
        }
    }

    private var borderColor: Color {
        if error != nil { return .accentRed }
        if isFocused { return .accentGreen }
        return .clear
    }
}
