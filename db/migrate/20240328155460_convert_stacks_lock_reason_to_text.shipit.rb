# This migration comes from shipit (originally 20151103144716)
class ConvertStacksLockReasonToText < ActiveRecord::Migration[4.2]
  def change
    change_column :stacks, :lock_reason, :string, limit: 4096
  end
end
