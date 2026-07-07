require 'xcodeproj'

project_path = 'LMS.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'LMS' }

group = project.main_group.find_subpath('LMS/Services', true)

['AccessibilityManager.swift', 'HapticManager.swift'].each do |filename|
  # Avoid adding duplicates
  existing_ref = group.files.find { |f| f.path == filename }
  if existing_ref
    puts "#{filename} already in group"
    ref = existing_ref
  else
    ref = group.new_reference(filename)
    puts "Added #{filename} to group"
  end

  # Add to target's source build phase
  unless target.source_build_phase.files_references.include?(ref)
    target.add_file_references([ref])
    puts "Added #{filename} to target build phase"
  end
end

project.save
puts "Project saved"
