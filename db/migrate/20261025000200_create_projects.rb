class CreateProjects < ActiveRecord::Migration[8.1]
  def up
    create_table :projects do |t|
      t.string :name, null: false
      t.string :path, null: false
      t.timestamps
    end
    add_index :projects, :path, unique: true
    add_reference :conversations, :project, foreign_key: true

    legacy_path = File.realpath(ENV.fetch("AGENT_WORKSPACE", Rails.root.join("workspace").to_s))
    now = connection.quote(Time.current)
    execute "INSERT INTO projects (name, path, created_at, updated_at) VALUES ('Legacy workspace', #{connection.quote(legacy_path)}, #{now}, #{now})"
    execute "UPDATE conversations SET project_id = (SELECT id FROM projects LIMIT 1)"
    change_column_null :conversations, :project_id, false
  end

  def down
    remove_reference :conversations, :project, foreign_key: true
    drop_table :projects
  end
end
