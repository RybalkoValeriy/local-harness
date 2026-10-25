class DirectoryBrowser
  LIMIT = 200

  def self.list(path = nil)
    directory = Pathname(ProjectRegistration.normalize_path(path.presence || Rails.root.parent.to_s)).realpath
    raise ArgumentError, "Choose a directory, not a file." unless directory.directory?
    directories = directory.children.sort.filter_map do |entry|
      next if entry.basename.to_s.start_with?(".") || !entry.directory?
      { name: entry.basename.to_s, path: entry.to_s }
    rescue SystemCallError
      nil
    end
    shortcuts = [ { name: "Linux home", path: Dir.home }, { name: "Project location", path: Rails.root.parent.to_s } ]
    Dir.glob("/mnt/[a-z]").select { |entry| File.directory?(entry) }.each do |drive|
      shortcuts << { name: "#{File.basename(drive).upcase}: drive", path: drive }
    end
    { path: directory.to_s, parent: directory.parent.to_s, directories: directories.first(LIMIT), truncated: directories.length > LIMIT, shortcuts: shortcuts }
  end
end
