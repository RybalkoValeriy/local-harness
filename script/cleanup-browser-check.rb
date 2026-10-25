report = JSON.parse(Rails.root.join("tmp/browser-projects-result.json").read)
report.fetch("paths").reverse_each do |path|
  raise "Unexpected smoke-test path" unless path.start_with?(Rails.root.join("tmp/browser-project-check-").to_s)
  project = Project.find_by(path: path)
  raise "Unexpected smoke-test project" if project && !project.name.start_with?("Browser ")
  project&.destroy!
end
puts "Removed only browser-check project records; fixture files remain in ignored tmp/."
