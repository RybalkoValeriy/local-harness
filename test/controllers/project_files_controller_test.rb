require "test_helper"
require "tmpdir"

class ProjectFilesControllerTest < ActionDispatch::IntegrationTest
  test "lists scoped folders and files and reflects new files" do
    Dir.mktmpdir do |directory|
      project = Project.create!(name: "Tree project", path: directory)
      Dir.mkdir(File.join(directory, "app"))
      Dir.mkdir(File.join(directory, "empty"))
      Dir.mkdir(File.join(directory, "node_modules"))
      File.write(File.join(directory, "README.md"), "hello")
      File.write(File.join(directory, ".env"), "hidden")
      File.symlink("/tmp", File.join(directory, "escape"))
      get files_project_path(project)
      assert_response :success
      assert_equal %w[app empty README.md], response.parsed_body["entries"].map { |entry| entry["name"] }
      get files_project_path(project), params: { path: "app" }
      assert_equal [], response.parsed_body["entries"]
      WorkspaceTools.new(root: directory).call("create_file", { "path" => "app/new.rb", "content" => "puts :hello" })
      get files_project_path(project), params: { path: "app" }
      assert_equal [ "app/new.rb" ], response.parsed_body["entries"].map { |entry| entry["path"] }
      %w[../ .env escape node_modules /tmp C:/Windows].each do |path|
        get files_project_path(project), params: { path: path }
        assert_response :unprocessable_entity
      end
    end
  end

  test "missing projects return not found" do
    get files_project_path(id: 0)
    assert_response :not_found
  end

  test "file viewer reads current project content and rejects unavailable paths" do
    Dir.mktmpdir do |directory|
      project = Project.create!(name: "File viewer", path: directory)
      File.write(File.join(directory, "hello.rb"), "class Hello; end\n")
      File.write(File.join(directory, "large.txt"), "a" * 16_001)
      File.write(File.join(directory, "binary.txt"), "\0")
      File.symlink("/etc/passwd", File.join(directory, "escape.txt"))
      get file_project_path(project), params: { path: "hello.rb" }
      assert_response :success
      assert_equal "class Hello; end\n", response.parsed_body["content"]
      assert_equal "no-store", response.headers["Cache-Control"]
      File.write(File.join(directory, "hello.rb"), "class Changed; end\n")
      get file_project_path(project), params: { path: "hello.rb" }
      assert_equal "class Changed; end\n", response.parsed_body["content"]
      get file_project_path(project), params: { path: "large.txt" }
      assert_equal true, response.parsed_body["truncated"]
      assert_equal 16_000, response.parsed_body["content"].bytesize
      [ "../outside.rb", ".env", "escape.txt", "node_modules/file.js", "binary.txt", "missing.rb", "/etc/passwd", "C:/hello.rb" ].each do |path|
        get file_project_path(project), params: { path: path }
        assert_response :unprocessable_entity
        assert response.parsed_body["error"]
      end
      File.unlink(File.join(directory, "hello.rb"))
      get file_project_path(project), params: { path: "hello.rb" }
      assert_response :unprocessable_entity
    end
  end
end
