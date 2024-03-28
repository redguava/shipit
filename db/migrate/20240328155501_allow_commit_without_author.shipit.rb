# This migration comes from shipit (originally 20180802172632)
class AllowCommitWithoutAuthor < ActiveRecord::Migration[5.1]
  def change
    change_column_null(:commits, :author_id, true)
    change_column_null(:commits, :committer_id, true)
  end
end
