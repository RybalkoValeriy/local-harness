require "test_helper"
require "tmpdir"

class WorkspaceToolsTest < ActiveSupport::TestCase
  test "creates nested files and edits one exact match without overwriting" do
    Dir.mktmpdir do |directory|
      tools = WorkspaceTools.new(root: directory)
      assert_equal "created", tools.call("create_file", { "path" => "app/hello.rb", "content" => "puts :hello\n" })[:action]
      path = File.join(directory, "app/hello.rb")
      assert_equal "puts :hello\n", File.read(path)
      assert tools.call("create_file", { "path" => "app/hello.rb", "content" => "overwrite" })[:error]
      File.chmod(0o640, path)
      assert_equal "edited", tools.call("edit_file", { "path" => "app/hello.rb", "old_text" => ":hello", "new_text" => ":world" })[:action]
      assert_equal "puts :world\n", File.read(path)
      assert_equal 0o640, File.stat(path).mode & 0o777
      assert tools.call("edit_file", { "path" => "app/hello.rb", "old_text" => ":hello", "new_text" => "oops" })[:error]
      File.write(path, "same same")
      assert tools.call("edit_file", { "path" => "app/hello.rb", "old_text" => "same", "new_text" => "oops" })[:error]
      assert_equal "same same", File.read(path)
    end
  end

  test "writes reject escapes symlinks secrets binaries and oversized content" do
    Dir.mktmpdir do |parent|
      directory = File.join(parent, "project")
      Dir.mkdir(directory)
      tools = WorkspaceTools.new(root: directory)
      File.symlink(parent, File.join(directory, "escape"))
      [ "../outside.rb", "/absolute.rb", "C:/outside.rb", "nested/../outside.rb", ".env", "config/credentials.yml", "node_modules/file.js", "escape/outside.rb", "image.png", "nested\\file.rb" ].each do |path|
        assert tools.call("create_file", { "path" => path, "content" => "unsafe" })[:error], path
      end
      [ "\0", "x" * 16_001, "\xFF".b ].each do |content|
        assert tools.call("create_file", { "path" => "bad.txt", "content" => content })[:error]
      end
      assert_not File.exist?(File.join(directory, "bad.txt"))
      File.write(File.join(parent, "outside.rb"), "outside")
      File.link(File.join(parent, "outside.rb"), File.join(directory, "linked.rb"))
      assert tools.call("edit_file", { "path" => "linked.rb", "old_text" => "outside", "new_text" => "changed" })[:error]
      assert_equal "outside", File.read(File.join(parent, "outside.rb"))
    end
  end

  test "separate projects write only to their own root" do
    Dir.mktmpdir do |parent|
      %w[AAA BBB].each do |name|
        directory = File.join(parent, name)
        Dir.mkdir(directory)
        WorkspaceTools.new(root: directory).call("create_file", { "path" => "hello.txt", "content" => name })
      end
      assert_equal "AAA", File.read(File.join(parent, "AAA/hello.txt"))
      assert_equal "BBB", File.read(File.join(parent, "BBB/hello.txt"))
    end
  end

  test "tools reject traversal, hidden files, and symlink escapes" do
    Dir.mktmpdir do |directory|
      previous = ENV["AGENT_WORKSPACE"]
      ENV["AGENT_WORKSPACE"] = directory
      File.write(File.join(directory, "hello.rb"), "puts :hello")
      File.write(File.join(directory, ".env"), "secret")
      File.symlink("/etc/passwd", File.join(directory, "escape.txt"))
      tools = WorkspaceTools.new
      assert_equal "puts :hello", tools.call("read_file", { "path" => "hello.rb" })[:content]
      assert tools.call("read_file", { "path" => "../outside.txt" })[:error]
      assert tools.call("read_file", { "path" => ".env" })[:error]
      assert tools.call("read_file", { "path" => "escape.txt" })[:error]
      assert_equal [ "hello.rb" ], tools.call("list_files", {})[:files]
    ensure
      ENV["AGENT_WORKSPACE"] = previous
    end
  end
end
