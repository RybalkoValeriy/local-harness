class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.string :title, null: false, default: "New conversation"
      t.timestamps
    end
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false, default: ""
      t.json :metadata, null: false, default: {}
      t.timestamps
    end
  end
end
