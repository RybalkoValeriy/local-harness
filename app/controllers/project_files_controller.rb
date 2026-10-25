class ProjectFilesController < ApplicationController
  def index
    response.headers["Cache-Control"] = "no-store"
    project = Project.find(params[:id])
    raise ArgumentError, "Project folder is unavailable" unless project.available?
    root = Pathname(project.path).realpath
    relative = params.fetch(:path, "")
    raise ArgumentError, "Use a relative project folder path" unless relative.is_a?(String) && !relative.include?("\\") && !relative.include?(":") && !relative.include?("\0") && !Pathname(relative).absolute?
    parts = relative.empty? ? [] : relative.split("/", -1)
    raise ArgumentError, "This folder is unavailable" if parts.any? { |part| part.empty? || part.start_with?(".") || excluded?(part) }
    directory = root
    parts.each do |part|
      directory = directory.join(part)
      raise ArgumentError, "Symlink folders are unavailable" if directory.symlink?
    end
    raise ArgumentError, "Folder is outside the project" unless directory.realpath == root || directory.realpath.to_s.start_with?("#{root}/")
    raise ArgumentError, "Path is not a folder" unless directory.directory?
    entries = directory.children.reject { |path| path.symlink? || path.basename.to_s.start_with?(".") || excluded?(path.basename.to_s) }
      .select { |path| path.directory? || path.file? }
      .sort_by { |path| [ path.directory? ? 0 : 1, path.basename.to_s.downcase ] }
    render json: { entries: entries.first(500).map { |path| { name: path.basename.to_s, path: path.relative_path_from(root).to_s, directory: path.directory? } }, truncated: entries.size > 500 }
  rescue ArgumentError, SystemCallError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def show
    project = Project.find(params[:id])
    raise ArgumentError, "Project folder is unavailable" unless project.available?
    relative = params.fetch(:path, "")
    raise ArgumentError, "Use a relative project file path" unless relative.is_a?(String) && relative.present? && !relative.include?("\\") && !relative.include?(":") && !relative.include?("\0") && !Pathname(relative).absolute?
    path = Pathname(project.path).realpath
    relative.split("/", -1).each do |part|
      raise ArgumentError, "This file is unavailable" if part.empty? || part.start_with?(".") || excluded?(part)
      path = path.join(part)
      raise ArgumentError, "Symlinks are unavailable" if path.symlink?
    end
    result = WorkspaceTools.new(root: project.path).call("read_file", { "path" => relative })
    response.headers["Cache-Control"] = "no-store"
    render json: result, status: result[:error] ? :unprocessable_entity : :ok
  rescue ArgumentError, SystemCallError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def excluded?(name)
    %w[node_modules vendor log tmp storage credentials].include?(name) || name.match?(/secret|credential|master\.key|\.env/i)
  end
end
