# This migration comes from shipit (originally 20161206105318)
class MakesStackIdNotNullOnStatuses < ActiveRecord::Migration[5.0]
  def change
    change_column_null :statuses, :stack_id, false
  end
end
