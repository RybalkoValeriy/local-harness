require "pathname"
require "tempfile"

class WorkspaceTools
  MAX_BYTES = 16_000
  MAX_FILES = 150
  TEXT_EXTENSIONS = %w[.rb .rake .ru .rbs .erb .js .jsx .ts .tsx .css .scss .sass .html .md .txt .json .yml .yaml .toml .csv .sh .sql .lock].freeze

  def self.root
    Pathname(ENV.fetch("AGENT_WORKSPACE", Rails.root.join("workspace").to_s)).realpath
  end

  def initialize(root: self.class.root)
    @root = Pathname(root).realpath
    raise ArgumentError, "Workspace is not a directory" unless @root.directory?
  end

  def self.definitions
    [
      { type: "function", function: { name: "list_files", description: "List readable files in the user's workspace.", parameters: { type: "object", properties: {}, additionalProperties: false } } },
      { type: "function", function: { name: "read_file", description: "Read a text file in the workspace, up to 16,000 bytes.", parameters: { type: "object", properties: { path: { type: "string", description: "Relative file path" } }, required: [ "path" ], additionalProperties: false } } },
      { type: "function", function: { name: "create_file", description: "Create a NEW text file in this project. Creates parent folders; never overwrites. Maximum 16,000 UTF-8 bytes.", parameters: { type: "object", properties: { path: { type: "string" }, content: { type: "string" } }, required: %w[path content], additionalProperties: false } } },
      { type: "function", function: { name: "edit_file", description: "Edit an existing project text file by replacing one exact unique old_text with new_text. Read it first. Refuses missing or ambiguous matches.", parameters: { type: "object", properties: { path: { type: "string" }, old_text: { type: "string" }, new_text: { type: "string" } }, required: %w[path old_text new_text], additionalProperties: false } } }
    ]
  end

  def call(name, arguments)
    case name
    when "list_files"
      # Limit traversal as well as the returned list, and never descend symlinks.
      files = []
      pending = [ @root ]
      visited = 0
      until pending.empty? || files.length >= MAX_FILES || visited >= 2000
        directory = pending.shift
        directory.children.sort.each do |path|
          visited += 1
          break if visited > 2000 || files.length >= MAX_FILES
          next if path.symlink? || path.basename.to_s.start_with?(".")
          next if %w[node_modules vendor log tmp storage credentials].include?(path.basename.to_s)
          if path.directory?
            pending << path
          elsif readable?(path)
            files << path.relative_path_from(@root).to_s
          end
        end
      end
      { files: files, limit: MAX_FILES }
    when "read_file"
      relative = arguments.fetch("path")
      raise ArgumentError, "Use a relative workspace path" unless relative.is_a?(String) && !Pathname(relative).absolute?
      raise ArgumentError, "Hidden files are unavailable" if Pathname(relative).each_filename.any? { |part| part.start_with?(".") }
      path = @root.join(relative).realpath
      raise ArgumentError, "Path is outside the workspace" unless path.to_s.start_with?("#{@root}/")
      raise ArgumentError, "Only ordinary text files are available" unless readable?(path)
      text = File.binread(path, MAX_BYTES + 1)
      raise ArgumentError, "Binary files are unavailable" if text.include?("\0")
      { path: relative, content: text.byteslice(0, MAX_BYTES).force_encoding("UTF-8").scrub, truncated: text.bytesize > MAX_BYTES }
    when "create_file"
      path = writable_path(arguments.fetch("path"))
      content = valid_text(arguments.fetch("content"))
      raise ArgumentError, "File already exists; use edit_file" if path.exist?
      create_parents(path.parent)
      File.open(path, File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW, 0o644) { |file| file.write(content) }
      { path: arguments["path"], action: "created", bytes: content.bytesize }
    when "edit_file"
      path = writable_path(arguments.fetch("path"))
      raise ArgumentError, "Only ordinary project files may be edited" unless path.file? && path.stat.nlink == 1
      old_text = valid_text(arguments.fetch("old_text"))
      new_text = valid_text(arguments.fetch("new_text"))
      raise ArgumentError, "old_text must not be empty" if old_text.empty?
      File.open(path, File::RDONLY | File::NOFOLLOW) do |file|
        original = valid_text(file.read(MAX_BYTES + 1))
        first = original.index(old_text)
        raise ArgumentError, "old_text must match exactly once; read the file again" unless first && !original.index(old_text, first + 1)
        updated = valid_text(original.sub(old_text) { new_text })
        Tempfile.create([ "harness-edit-", ".tmp" ], path.parent) do |temporary|
          temporary.binmode
          temporary.chmod(file.stat.mode & 0o777)
          temporary.write(updated)
          temporary.flush
          temporary.fsync
          raise ArgumentError, "File changed during editing; read it again" unless path.binread == original
          File.rename(temporary.path, path)
        end
        return { path: arguments["path"], action: "edited", bytes: updated.bytesize }
      end
    else
      raise ArgumentError, "Unknown tool: #{name}"
    end
  rescue ArgumentError, KeyError, SystemCallError => e
    { error: e.message }
  end

  private

  def writable_path(relative)
    raise ArgumentError, "Use a relative project path with forward slashes" unless relative.is_a?(String) && relative.present? && !relative.include?("\\") && !relative.include?(":") && !relative.include?("\0") && !Pathname(relative).absolute?
    parts = relative.split("/", -1)
    raise ArgumentError, "Hidden, empty and traversal paths are unavailable" if parts.any? { |part| part.empty? || part.start_with?(".") }
    raise ArgumentError, "Dependency and runtime folders are unavailable" if parts.any? { |part| %w[node_modules vendor log tmp storage credentials].include?(part) }
    path = @root
    parts.each do |part|
      path = path.join(part)
      raise ArgumentError, "Symlinks are unavailable for writing" if path.symlink?
    end
    raise ArgumentError, "Only ordinary text file types are available" unless text_path?(path)
    path
  end

  def create_parents(parent)
    current = @root
    parent.relative_path_from(@root).each_filename do |part|
      next if part == "."
      current = current.join(part)
      raise ArgumentError, "Symlink folders are unavailable" if current.symlink?
      Dir.mkdir(current) unless current.exist?
      raise ArgumentError, "Parent must be a directory" unless current.directory?
    end
  end

  def valid_text(text)
    raise ArgumentError, "Text must be a string of at most 16,000 UTF-8 bytes" unless text.is_a?(String) && text.bytesize <= MAX_BYTES
    text = text.dup.force_encoding("UTF-8")
    raise ArgumentError, "Binary or invalid UTF-8 content is unavailable" unless text.valid_encoding? && !text.include?("\0")
    text
  end

  def readable?(path)
    path.file? && text_path?(path)
  end

  def text_path?(path)
    !path.basename.to_s.match?(/secret|credential|master\.key|\.env/i) &&
      (TEXT_EXTENSIONS.include?(path.extname.downcase) || %w[Gemfile Rakefile Dockerfile LICENSE].include?(path.basename.to_s))
  end
end
