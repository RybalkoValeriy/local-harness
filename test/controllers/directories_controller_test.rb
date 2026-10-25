require "test_helper"
require "tmpdir"

class DirectoriesControllerTest < ActionDispatch::IntegrationTest
  test "browses directories without returning files or hidden entries" do
    Dir.mktmpdir do |parent|
      Dir.mkdir(File.join(parent, "AAA"))
      Dir.mkdir(File.join(parent, ".hidden"))
      File.write(File.join(parent, "private.txt"), "not returned")
      get directories_path, params: { path: parent }, as: :json
      assert_response :success
      listing = response.parsed_body
      assert_equal File.realpath(parent), listing.fetch("path")
      assert_equal [ "AAA" ], listing.fetch("directories").map { |entry| entry.fetch("name") }
      assert listing.fetch("shortcuts").any?
      get directories_path, params: { path: "relative" }, as: :json
      assert_response :unprocessable_entity
      assert_includes response.parsed_body.fetch("error"), "absolute"
    end
  end

  test "accepts quoted Windows paths and exposes folders for selecting a parent" do
    windows_root = Rails.root.to_s.sub("/mnt/c/", "C:/")
    get directories_path, params: { path: "\"#{windows_root}\"" }, as: :json
    assert_response :success
    assert_equal Rails.root.realpath.to_s, response.parsed_body.fetch("path")
    assert response.parsed_body.fetch("directories").any? { |entry| entry.fetch("name") == "app" }
  end
end
