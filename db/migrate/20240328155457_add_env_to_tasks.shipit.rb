# This migration comes from shipit (originally 20150814182557)
class AddEnvToTasks < ActiveRecord::Migration[4.2]
  def change
    add_column :tasks, :env, :text
  end
end
