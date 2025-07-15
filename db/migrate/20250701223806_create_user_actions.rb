class CreateUserActions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_actions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :action, null: false, foreign_key: true
      t.datetime :last_performed_at

      t.timestamps
    end
  end
end
