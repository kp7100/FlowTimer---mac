from pbxproj import XcodeProject

project_path = "FlowTimer.xcodeproj/project.pbxproj"
project = XcodeProject.load(project_path)

# Find all build files in the project
build_files = project.objects.get_objects_in_section("PBXBuildFile")

# Find build files that refer to FlowCloseButton.swift
seen_file_refs = set()
duplicates_removed = 0

for bf in build_files:
    file_ref_id = bf.fileRef
    file_ref = project.objects.get(file_ref_id)
    
    if file_ref and getattr(file_ref, 'name', None) == "FlowCloseButton.swift" or getattr(file_ref, 'path', None) == "FlowCloseButton.swift" or (getattr(file_ref, 'path', None) and "FlowCloseButton.swift" in getattr(file_ref, 'path', "")):
        # Check if we already have this file in Compile Sources (or just globally for this target)
        if file_ref_id in seen_file_refs:
            # It's a duplicate PBXBuildFile for the same file reference
            project.remove_build_file(bf.get_id())
            duplicates_removed += 1
            print(f"Removed duplicate build file {bf.get_id()} for {file_ref.get('path', file_ref.get('name'))}")
        else:
            seen_file_refs.add(file_ref_id)

project.save()
print(f"Total duplicates removed: {duplicates_removed}")
