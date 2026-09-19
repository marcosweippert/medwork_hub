class CreateApiKeys < ActiveRecord::Migration[7.1]
  def change
    create_table :api_keys do |t|
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.boolean :enabled, default: true, null: false
      t.date :renewal_on
      t.datetime :last_used_at
      t.bigint :user_id
      t.timestamps
    end

    add_index :api_keys, :token_digest, unique: true
    add_index :api_keys, :user_id
    add_foreign_key :api_keys, :users
  end
end
