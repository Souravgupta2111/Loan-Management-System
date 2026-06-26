//
//  NotificationTemplatesView.swift
//  LMS Staff
//
//  Alert Notification Templates editor with validation checks for placeholder tags.
//

import SwiftUI

struct NotificationTemplatesView: View {
    @State private var templates: [NotificationTemplate] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @State private var selectedTemplate: NotificationTemplate?
    @State private var editorText: String = ""
    @State private var validationErrorMessage: String? = nil
    @State private var isSaving = false
    
    private let service = NotificationTemplateService.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // Left list of templates
            VStack(alignment: .leading, spacing: 0) {
                Text("Alert Templates")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                
                Divider()
                    .background(Color.staffBorder)
                    .padding(.vertical, StaffSpacing.md)
                
                if isLoading {
                    Spacer()
                    ProgressView("Loading templates...")
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if templates.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "envelope.fill", title: "No Templates", message: "No notification templates found in database.")
                    Spacer()
                } else {
                    List(templates, selection: $selectedTemplate) { template in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.eventName.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.staffBody)
                                .fontWeight(.bold)
                                .foregroundColor(.staffTextPrimary)
                            Text(template.description ?? "")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        .padding(.vertical, 4)
                        .tag(template)
                        .listRowBackground(Color.staffSurface)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.staffBackground)
                }
            }
            .frame(width: 320)
            .background(Color.staffBackground)
            
            Divider()
                .background(Color.staffBorder)
            
            // Right Template Editor
            if let template = selectedTemplate {
                templateEditorConsole(template)
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "envelope.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                    Text("Select a Template to Edit Alert Copy")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.staffSurface.opacity(0.1))
            }
        }
        .background(Color.staffBackground)
        .onAppear {
            loadTemplates()
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func loadTemplates() {
        Task {
            isLoading = true
            do {
                self.templates = try await service.fetchTemplates()
            } catch {
                self.errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    // MARK: - Template Editor Panel
    
    @ViewBuilder
    private func templateEditorConsole(_ item: NotificationTemplate) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.eventName.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                    Text("Event trigger: \(item.eventName)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                Spacer()
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    // Placeholders reference card
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Supported Dynamic Tags")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Text("The template will automatically format when dispatched by replacing the tags below:")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                            
                            Divider()
                            
                            let placeholders = item.supportedPlaceholders ?? []
                            if placeholders.isEmpty {
                                Text("No dynamic tags supported for this event.")
                                    .font(.staffBody)
                                    .foregroundColor(.staffTextSecondary)
                            } else {
                                ForEach(placeholders, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.staffAccent)
                                }
                            }
                        }
                    }
                    
                    // Copy Editor
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Template Message Text Copy")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            TextEditor(text: $editorText)
                                .frame(height: 120)
                                .padding(8)
                                .background(Color.staffSurfaceMuted)
                                .cornerRadius(StaffCorner.md)
                                .foregroundColor(.staffTextPrimary)
                                .tint(.staffAccent)
                                .onChange(of: editorText) { newValue in
                                    validateTemplateCopy(newValue, placeholders: item.supportedPlaceholders ?? [])
                                }
                            
                            if let error = validationErrorMessage {
                                Text(error)
                                    .font(.staffCaption)
                                    .foregroundColor(.staffRed)
                                    .fontWeight(.medium)
                            } else {
                                Text("✓ Template markup placeholders are syntactically valid.")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffGreen)
                            }
                        }
                    }
                }
                .padding(StaffSpacing.lg)
            }
            
            Divider()
                .background(Color.staffBorder)
            
            // Footer: Save
            HStack {
                Spacer()
                StaffButton(
                    title: "Save Template changes",
                    style: .primary,
                    icon: "checkmark.circle.fill"
                ) {
                    Task {
                        isSaving = true
                        do {
                            if try await service.updateTemplate(id: item.id, templateText: editorText) {
                                if let index = templates.firstIndex(where: { $0.id == item.id }) {
                                    templates[index].templateText = editorText
                                    selectedTemplate = templates[index]
                                }
                            }
                        } catch {
                            self.errorMessage = error.localizedDescription
                        }
                        isSaving = false
                    }
                }
                .disabled(validationErrorMessage != nil || editorText.isEmpty || isSaving)
                .frame(width: 280)
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
        }
        .onAppear {
            editorText = item.templateText
        }
        .onChange(of: item) { newItem in
            editorText = newItem.templateText
        }
    }
    
    // MARK: - Validation Logic
    
    private func validateTemplateCopy(_ text: String, placeholders: [String]) {
        validationErrorMessage = nil
        
        // 1. Detect open but unclosed or broken brackets
        let regex = "\\{\\{[a-zA-Z_0-9]*"
        let brokenRegex = try? NSRegularExpression(pattern: regex, options: [])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let matches = brokenRegex?.matches(in: text, options: [], range: range) {
            for match in matches {
                if let matchRange = Range(match.range, in: text) {
                    let substring = String(text[matchRange])
                    // If it does not end with closed brackets, it's broken
                    let matchingCloseIndex = match.range.location + match.range.length
                    if matchingCloseIndex >= text.count || !text.contains(substring + "}}") {
                        validationErrorMessage = "Broken tag syntax detected near '\(substring)'. Ensure it ends with '}}'."
                        return
                    }
                }
            }
        }
        
        // 2. Detect unsupported placeholder tags
        let tagPattern = "\\{\\{[a-zA-Z_0-9]+\\}\\}"
        let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: [])
        if let matches = tagRegex?.matches(in: text, options: [], range: range) {
            for match in matches {
                if let matchRange = Range(match.range, in: text) {
                    let tag = String(text[matchRange])
                    if !placeholders.contains(tag) {
                        validationErrorMessage = "Unsupported placeholder tag '\(tag)' is not registered for this event."
                        return
                    }
                }
            }
        }
    }
}
