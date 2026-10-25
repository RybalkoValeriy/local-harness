class Project < ApplicationRecord
  has_many :conversations, dependent: :restrict_with_error
  validates :name, presence: true, length: { maximum: 100 }
  validates :path, presence: true, uniqueness: true

  def self.legacy_workspace
    path = File.realpath(ENV.fetch("AGENT_WORKSPACE", Rails.root.join("workspace").to_s))
    find_or_create_by!(path: path) { |project| project.name = "Legacy workspace" }
  end

  def available?
    File.directory?(path) && File.realpath(path) == path
  rescue SystemCallError
    false
  end
end
