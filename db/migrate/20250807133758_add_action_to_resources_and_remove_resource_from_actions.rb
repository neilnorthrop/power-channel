class AddActionToResourcesAndRemoveResourceFromActions < ActiveRecord::Migration[8.0]
  def change
    add_reference :resources, :action, null: true, foreign_key: true
    remove_reference :actions, :resource, null: false, foreign_key: true
  end
end
