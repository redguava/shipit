# This migration comes from shipit (originally 20150518214944)
class AddIgnoreCiToStack < ActiveRecord::Migration[4.2]
  def change
    add_column :stacks, :ignore_ci, :boolean
  end
end
