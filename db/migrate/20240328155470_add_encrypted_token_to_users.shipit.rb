# This migration comes from shipit (originally 20160303203940)
class AddEncryptedTokenToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :encrypted_github_access_token, :string
    add_column :users, :encrypted_github_access_token_iv, :string
  end
end
