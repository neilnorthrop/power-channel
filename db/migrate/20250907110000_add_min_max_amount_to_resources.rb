class AddMinMaxAmountToResources < ActiveRecord::Migration[8.0]
  def change
    add_column :resources, :min_amount, :integer
    add_column :resources, :max_amount, :integer
  end
end
