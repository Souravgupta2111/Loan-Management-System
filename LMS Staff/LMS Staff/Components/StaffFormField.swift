import SwiftUI

/// Staff-themed form input field with dark background styling
struct StaffFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var error: String? = nil
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
    var icon: String? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.sm) {
            Text(label)
                .font(.staffLabel)
                .foregroundColor(.staffTextSecondary)

            HStack(spacing: StaffSpacing.md) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isFocused ? .staffAccent : .staffTextTertiary)
                        .frame(width: 20)
                }

                 Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                    }
                }
                .font(.staffBody)
                .foregroundColor(.staffTextPrimary)
                .tint(.staffAccent)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.staffSurfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: StaffCorner.md))
            .overlay(
                RoundedRectangle(cornerRadius: StaffCorner.md)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .focused($isFocused)

            if let error = error, !error.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text(error)
                        .font(.staffCaption)
                }
                .foregroundColor(.staffRed)
            }
        }
    }

    private var borderColor: Color {
        if error != nil && !(error?.isEmpty ?? true) { return .staffRed }
        if isFocused { return .staffAccent }
        return .staffBorder
    }
}

/// Staff-themed text editor for multi-line input
struct StaffTextEditor: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var error: String? = nil
    var minHeight: CGFloat = 100

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.sm) {
            Text(label)
                .font(.staffLabel)
                .foregroundColor(.staffTextSecondary)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.staffBody)
                    .foregroundColor(.staffTextPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: minHeight)
                    .focused($isFocused)

                if text.isEmpty {
                    Text(placeholder)
                        .font(.staffBody)
                        .foregroundColor(.staffTextTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .padding(12)
            .background(Color.staffSurfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: StaffCorner.md))
            .overlay(
                RoundedRectangle(cornerRadius: StaffCorner.md)
                    .stroke(isFocused ? Color.staffAccent : Color.staffBorder, lineWidth: 1.5)
            )

            if let error = error, !error.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text(error)
                        .font(.staffCaption)
                }
                .foregroundColor(.staffRed)
            }
        }
    }
}
