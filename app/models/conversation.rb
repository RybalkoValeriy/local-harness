class Conversation < ApplicationRecord
  belongs_to :project, default: -> { Project.legacy_workspace }
  has_many :messages, -> { order(:id) }, dependent: :destroy
  validates :title, presence: true
end
