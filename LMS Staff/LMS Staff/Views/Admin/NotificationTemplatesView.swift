//
//  NotificationTemplatesView.swift
//  LMS Staff
//
//  Alert Notification Templates editor with full CRUD — edit all fields,
//  toggle active status, create new templates, and delete existing ones.
//

import SwiftUI

struct NotificationTemplatesView: View {
    @State private var templates: [NotificationTemplate] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @State private var selectedTemplate: NotificationTemplate?
    
    // Editor state
    @State private var editorEventName: String = ""
    @State private var editorText: String = ""
    @State private var editorDescription: String = ""
    @State private var editorPlaceholders: String = ""
    @State private var editorIsActive: Bool = true
    @State private var validationErrorMessage: String? = nil
    @State private var isSaving = false
    
    // Create sheet
    @State private var showCreateSheet = false
    @State private var newEventName: String = ""
    @State private var newTemplateText: String = ""
    @State private var newDescription: String = ""
    @State private var newPlaceholders: String = ""
    
    // Delete confirmation
    @State private var showDeleteConfirm = false
    
    private let service = NotificationTemplateService.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // Left list of templates
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Alert Templates")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        newEventName = ""
                        newTemplateText = ""
                        newDescription = ""
                        newPlaceholders = ""
                        showCreateSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.staffAccent)
                    }
                }
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
                    EmptyStateView(icon: "envelope.fill", title: "No Templates", message: "No notification templates found. Tap '+' to create one.")
                    Spacer()
                } else {
                    List(templates, selection: $selectedTemplate) { template in
                        HStack(spacing: StaffSpacing.sm) {
                            Circle()
                                .fill(template.isActive ? Color.staffGreen : Color.staffTextSecondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.eventName.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                Text(template.description ?? "")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                                    .lineLimit(2)
                            }
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
            .frame(width: 340)
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
                    Text("Select a Template to Edit")
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
        .sheet(isPresented: $showCreateSheet) {
            createTemplateSheet
        }
        .alert("Delete Template?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                guard let template = selectedTemplate else { return }
                Task {
                    do {
                        try await service.deleteTemplate(id: template.id)
                        selectedTemplate = nil
                        loadTemplates()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the template. This action cannot be undone.")
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
                
                // Active toggle
                HStack(spacing: StaffSpacing.sm) {
                    Text(editorIsActive ? "Active" : "Inactive")
                        .font(.staffCaption)
                        .foregroundColor(editorIsActive ? .staffGreen : .staffTextSecondary)
                        .fontWeight(.bold)
                    Toggle("", isOn: $editorIsActive)
                        .labelsHidden()
                        .tint(.staffGreen)
                }
                
                // Delete button
                Button(action: {
                    showDeleteConfirm = true
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.staffRed)
                }
                .padding(.leading, StaffSpacing.md)
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    
                    // Event Name Editor
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Event Name")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Text("The unique event trigger identifier (use snake_case).")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                            
                            Divider()
                            
                            TextField("e.g. loan_approved", text: $editorEventName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(10)
                                .background(Color.staffSurfaceMuted)
                                .cornerRadius(StaffCorner.md)
                                .foregroundColor(.staffTextPrimary)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    // Description Editor
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Template Description")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            TextField("Brief description of when this template is used", text: $editorDescription)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(10)
                                .background(Color.staffSurfaceMuted)
                                .cornerRadius(StaffCorner.md)
                                .foregroundColor(.staffTextPrimary)
                        }
                    }
                    
                    // Placeholders Editor
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Supported Dynamic Tags")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Text("Comma-separated list of placeholder tags (e.g. {{borrower_name}}, {{amount}}).")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                            
                            Divider()
                            
                            TextField("{{tag1}}, {{tag2}}, ...", text: $editorPlaceholders)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(10)
                                .background(Color.staffSurfaceMuted)
                                .cornerRadius(StaffCorner.md)
                                .foregroundColor(.staffAccent)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    // Copy Editor
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Template Message Text")
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
                                    let placeholders = parsePlaceholders(editorPlaceholders)
                                    validateTemplateCopy(newValue, placeholders: placeholders)
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
                    title: "Save All Changes",
                    style: .primary,
                    icon: "checkmark.circle.fill"
                ) {
                    Task {
                        isSaving = true
                        do {
                            let placeholderArray = parsePlaceholders(editorPlaceholders)
                            if try await service.updateTemplateFull(
                                id: item.id,
                                eventName: editorEventName,
                                templateText: editorText,
                                description: editorDescription,
                                isActive: editorIsActive,
                                supportedPlaceholders: placeholderArray
                            ) {
                                // Update local state
                                if let index = templates.firstIndex(where: { $0.id == item.id }) {
                                    templates[index].eventName = editorEventName
                                    templates[index].templateText = editorText
                                    templates[index].description = editorDescription
                                    templates[index].isActive = editorIsActive
                                    templates[index].supportedPlaceholders = placeholderArray
                                    selectedTemplate = templates[index]
                                }
                            }
                        } catch {
                            self.errorMessage = error.localizedDescription
                        }
                        isSaving = false
                    }
                }
                .disabled(validationErrorMessage != nil || editorText.isEmpty || editorEventName.isEmpty || isSaving)
                .frame(width: 280)
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
        }
        .onAppear {
            syncEditor(with: item)
        }
        .onChange(of: item) { newItem in
            syncEditor(with: newItem)
        }
    }
    
    private func syncEditor(with item: NotificationTemplate) {
        editorEventName = item.eventName
        editorText = item.templateText
        editorDescription = item.description ?? ""
        editorIsActive = item.isActive
        editorPlaceholders = (item.supportedPlaceholders ?? []).joined(separator: ", ")
        validationErrorMessage = nil
    }
    
    private func parsePlaceholders(_ text: String) -> [String] {
        text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    // MARK: - Create Template Sheet
    
    private var createTemplateSheet: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: StaffSpacing.xl) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.staffAccent)
                        .padding(.top, StaffSpacing.xl)
                    
                    Text("Create New Notification Template")
                        .font(.staffSectionTitle)
                        .foregroundColor(.staffTextPrimary)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Event Name (snake_case) *", placeholder: "e.g. loan_approved", text: $newEventName, icon: "tag")
                        StaffFormField(label: "Description", placeholder: "Brief description of the event trigger", text: $newDescription, icon: "text.alignleft")
                        StaffFormField(label: "Supported Placeholders (comma-separated)", placeholder: "{{borrower_name}}, {{amount}}, {{loan_id}}", text: $newPlaceholders, icon: "curlybraces")
                        StaffTextEditor(label: "Template Text *", placeholder: "Write the notification message...", text: $newTemplateText, minHeight: 120)
                    }
                    .padding(.horizontal, StaffSpacing.xl)
                    
                    StaffButton(title: "Create Template", style: .primary, icon: "plus.circle.fill") {
                        Task {
                            do {
                                let placeholderArray = parsePlaceholders(newPlaceholders)
                                let _ = try await service.createTemplate(
                                    eventName: newEventName.trimmingCharacters(in: .whitespacesAndNewlines),
                                    templateText: newTemplateText,
                                    description: newDescription,
                                    placeholders: placeholderArray
                                )
                                showCreateSheet = false
                                loadTemplates()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(newEventName.isEmpty || newTemplateText.isEmpty)
                    .padding(.horizontal, StaffSpacing.xl)
                    .padding(.bottom, StaffSpacing.xl)
                }
            }
            .background(Color.staffBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showCreateSheet = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.staffAccent)
                }
            }
        }
        .presentationBackground(Color.staffBackground)
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
        
        // 2. Detect unsupported placeholder tags (only if placeholders are defined)
        guard !placeholders.isEmpty else { return }
        
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
