require "test_helper"
require "tmpdir"

class ProjectRegistrationTest < ActiveSupport::TestCase
  test "registers existing directory without modifying its contents and rejects duplicates" do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "README.md"), "keep me")
      project = ProjectRegistration.call(name: "AAA", path: directory, mode: "existing")
      assert project.persisted?, project.errors.full_messages.join(", ")
      assert_equal File.realpath(directory), project.path
      assert_equal [ "README.md" ], Dir.children(directory)
      duplicate = ProjectRegistration.call(name: "BBB", path: "#{directory}/.", mode: "existing")
      assert_not duplicate.persisted?
      assert duplicate.errors[:path].any?
    end
  end

  test "creates exactly one new directory and refuses overwrite or traversal" do
    Dir.mktmpdir do |parent|
      project = ProjectRegistration.call(name: "AAA", path: parent, mode: "new", folder: "AAA")
      assert project.persisted?, project.errors.full_messages.join(", ")
      assert Dir.exist?(File.join(parent, "AAA"))
      File.write(File.join(parent, "AAA", "keep.txt"), "untouched")
      assert_not ProjectRegistration.call(name: "Again", path: parent, mode: "new", folder: "AAA").persisted?
      assert_equal "untouched", File.read(File.join(parent, "AAA", "keep.txt"))
      assert_not ProjectRegistration.call(name: "Bad", path: parent, mode: "new", folder: "../escape").persisted?
      assert_equal [ "AAA" ], Dir.children(parent)
      assert_not ProjectRegistration.call(name: "", path: parent, mode: "new", folder: "invalid").persisted?
      assert_not Dir.exist?(File.join(parent, "invalid"))
    end
  end

  test "normalizes Windows paths and rejects relative or unavailable directories" do
    assert_equal "/mnt/c/Users/Valeriy/AAA", ProjectRegistration.normalize_path('C:\\Users\\Valeriy\\AAA')
    assert_equal "/mnt/d/Projects", ProjectRegistration.normalize_path("D:/Projects")
    assert_equal "/mnt/c/Users/Valeriy/AAA", ProjectRegistration.normalize_path('"C:\Users\Valeriy\AAA"')
    assert_equal Dir.home, ProjectRegistration.normalize_path("~")
    assert_not ProjectRegistration.call(name: "Bad", path: "relative", mode: "existing").persisted?
    assert_not ProjectRegistration.call(name: "Bad", path: "/not-a-real-project-path", mode: "existing").persisted?
  end
end
