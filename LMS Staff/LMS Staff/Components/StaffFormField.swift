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
    var inputSanitizer: ((String) -> String)? = nil
    var onInvalidInput: (() -> Void)? = nil

    @State private var isPasswordVisible: Bool = false
    @State private var isUIKitFocused: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.sm) {
            Text(label)
                .font(.staffLabel)
                .foregroundColor(.staffTextSecondary)

            HStack(spacing: StaffSpacing.md) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(isFocused ? .staffAccent : .staffTextTertiary)
                        .frame(width: 20)
                }

                Group {
                    if isSecure && !isPasswordVisible {
                        ZStack(alignment: .leading) {
                            if text.isEmpty {
                                Text(placeholder)
                                    .font(.staffBody)
                                    .foregroundColor(.staffTextTertiary)
                                    .allowsHitTesting(false)
                            }
                            SecureField("", text: $text)
                        }
                    } else {
                        ZStack(alignment: .leading) {
                            if text.isEmpty {
                                Text(placeholder)
                                    .font(.staffBody)
                                    .foregroundColor(.staffTextTertiary)
                                    .allowsHitTesting(false)
                            }
                            if let inputSanitizer {
                                SanitizedTextField(
                                    text: $text,
                                    keyboardType: keyboardType,
                                    autocapitalization: autocapitalization,
                                    sanitizer: inputSanitizer,
                                    onInvalidInput: onInvalidInput,
                                    isFocused: $isUIKitFocused
                                )
                            } else {
                                TextField("", text: $text)
                                    .keyboardType(keyboardType)
                                    .textInputAutocapitalization(autocapitalization)
                            }
                        }
                    }
                }
                .font(.staffBody)
                .foregroundColor(.staffTextPrimary)
                .tint(.staffAccent)
                .autocorrectionDisabled()
                
                if isSecure {
                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.staffTextSecondary)
                    }
                }
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
                        .font(.caption)
                    Text(error)
                        .font(.staffCaption)
                }
                .foregroundColor(.staffRed)
            }
        }
    }

    private var borderColor: Color {
        if error != nil && !(error?.isEmpty ?? true) { return .staffRed }
        if isFocused || isUIKitFocused { return .staffAccent }
        return .staffBorder
    }
}

private struct SanitizedTextField: UIViewRepresentable {
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let autocapitalization: TextInputAutocapitalization
    let sanitizer: (String) -> String
    let onInvalidInput: (() -> Void)?
    @Binding var isFocused: Bool

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.textColor = UIColor(Color.staffTextPrimary)
        textField.tintColor = UIColor(Color.staffAccent)
        textField.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        textField.keyboardType = keyboardType
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        if textField.text != text {
            textField.text = text
        }
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = .none
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SanitizedTextField

        init(parent: SanitizedTextField) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.isFocused = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isFocused = false
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            guard let textRange = Range(range, in: current) else { return false }
            let proposed = current.replacingCharacters(in: textRange, with: string)
            let sanitized = parent.sanitizer(proposed)

            guard sanitized == proposed else {
                parent.onInvalidInput?()
                textField.text = sanitized
                parent.text = sanitized
                return false
            }

            return true
        }

        @objc func textDidChange(_ textField: UITextField) {
            let current = textField.text ?? ""
            let sanitized = parent.sanitizer(current)
            if sanitized != current {
                parent.onInvalidInput?()
                textField.text = sanitized
            }
            parent.text = sanitized
        }
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
                        .font(.caption)
                    Text(error)
                        .font(.staffCaption)
                }
                .foregroundColor(.staffRed)
            }
        }
    }
}
