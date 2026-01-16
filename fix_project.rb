require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
# Find the 'Runner' group safely
group = project.main_group.children.find { |c| c.isa == 'PBXGroup' && (c.name == 'Runner' || c.path == 'Runner') }

if group.nil?
  puts "Error: Could not find 'Runner' group."
  exit 1
end

# Check if file is already there (though grep said no, good to be safe)
file_ref = group.find_file_by_path('GoogleService-Info.plist')

unless file_ref
  puts "Adding GoogleService-Info.plist to project..."
  file_ref = group.new_file('GoogleService-Info.plist')
  
  target = project.targets.find { |t| t.name == 'Runner' }
  target.add_resources([file_ref])
  
  project.save
  puts "Project saved."
else
  puts "GoogleService-Info.plist already exists in project."
end
