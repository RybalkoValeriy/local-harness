require "pathname"

class ProjectRegistration
  def self.normalize_path(value)
    path = value.to_s.strip.tr("\\", "/")
    path = path[1...-1].strip if path.length >= 2 && [ '"', "'" ].include?(path[0]) && path[-1] == path[0]
    path = File.expand_path(path) if path == "~" || path.start_with?("~/")
    path = "/mnt/#{path[0].downcase}#{path[2..]}" if path.match?(/\A[A-Za-z]:\//)
    raise ArgumentError, "Enter an absolute Linux or Windows drive path." unless Pathname(path).absolute?
    path
  end

  def self.call(name: nil, path: nil, mode: nil, folder: nil)
    project = Project.new(name: name.to_s.strip)
    project.path = path.to_s
    created_path = nil
    begin
      canonical = Pathname(normalize_path(path)).realpath
      raise ArgumentError, "Choose an existing directory." unless canonical.directory?
      case mode
      when "existing"
        project.path = canonical.to_s
        project.save!
      when "new"
        unless folder.is_a?(String) && folder.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}\z/)
          raise ArgumentError, "Folder name must use letters, numbers, hyphens or underscores (up to 80 characters)."
        end
        target = canonical.join(folder)
        project.path = target.to_s
        project.validate!
        Dir.mkdir(target)
        created_path = target
        project.save!
      else
        raise ArgumentError, "Choose create project or open existing folder."
      end
    rescue ActiveRecord::RecordInvalid
      # Validation messages are already attached to the project.
    rescue ActiveRecord::RecordNotUnique
      project.errors.add(:path, "is already registered")
    rescue ArgumentError, SystemCallError => e
      project.errors.add(:base, e.message)
    ensure
      Dir.rmdir(created_path) if created_path && !project.persisted? && created_path.directory? && created_path.children.empty?
    end
    project
  end
end
