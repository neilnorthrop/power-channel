# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_07_101500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "actions", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "cooldown"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "order", default: 1000, null: false
    t.index ["order"], name: "index_actions_on_order"
  end

  create_table "active_effects", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "effect_id", null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["effect_id"], name: "index_active_effects_on_effect_id"
    t.index ["expires_at"], name: "index_active_effects_on_expires_at"
    t.index ["user_id"], name: "index_active_effects_on_user_id"
  end

  create_table "buildings", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "level"
    t.string "effect"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "dismantle_rules", force: :cascade do |t|
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subject_type", "subject_id"], name: "index_dismantle_rules_on_subject", unique: true
  end

  create_table "dismantle_yields", force: :cascade do |t|
    t.bigint "dismantle_rule_id", null: false
    t.string "component_type", null: false
    t.bigint "component_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "salvage_rate", precision: 5, scale: 2, default: "1.0", null: false
    t.string "quality"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dismantle_rule_id", "component_type", "component_id"], name: "index_dismantle_yields_on_rule_component"
    t.index ["dismantle_rule_id"], name: "index_dismantle_yields_on_dismantle_rule_id"
  end

  create_table "effects", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "target_attribute"
    t.string "modifier_type"
    t.float "modifier_value"
    t.integer "duration"
    t.string "effectable_type", null: false
    t.bigint "effectable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["effectable_type", "effectable_id"], name: "index_effects_on_effectable"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "level", default: "info", null: false
    t.text "message", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["level"], name: "index_events_on_level"
    t.index ["user_id", "created_at"], name: "index_events_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "flag_requirements", force: :cascade do |t|
    t.bigint "flag_id", null: false
    t.string "requirement_type", null: false
    t.bigint "requirement_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "logic", default: "AND", null: false
    t.index ["flag_id"], name: "index_flag_requirements_on_flag_id"
    t.index ["logic"], name: "index_flag_requirements_on_logic"
    t.index ["requirement_type", "requirement_id"], name: "index_flag_requirements_on_req"
  end

  create_table "flags", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_flags_on_slug", unique: true
  end

  create_table "items", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "effect"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "drop_chance", default: 1.0
  end

  create_table "recipe_resources", force: :cascade do |t|
    t.bigint "recipe_id", null: false
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "component_type", null: false
    t.bigint "component_id", null: false
    t.index ["component_type", "component_id"], name: "index_recipe_resources_on_component"
    t.index ["recipe_id", "component_type", "component_id"], name: "index_recipe_resources_unique_component", unique: true
    t.index ["recipe_id"], name: "index_recipe_resources_on_recipe_id"
  end

  create_table "recipes", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_recipes_on_item_id"
  end

  create_table "resources", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "base_amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "action_id"
    t.float "drop_chance", default: 1.0
    t.index ["action_id"], name: "index_resources_on_action_id"
  end

  create_table "skills", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "cost"
    t.string "effect"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "multiplier"
  end

  create_table "unlockables", force: :cascade do |t|
    t.bigint "flag_id", null: false
    t.string "unlockable_type", null: false
    t.bigint "unlockable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["flag_id", "unlockable_type", "unlockable_id"], name: "index_unlockables_unique", unique: true
    t.index ["flag_id"], name: "index_unlockables_on_flag_id"
    t.index ["unlockable_type", "unlockable_id"], name: "index_unlockables_on_unlockable"
  end

  create_table "user_actions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "action_id", null: false
    t.datetime "last_performed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "level", default: 1
    t.index ["action_id"], name: "index_user_actions_on_action_id"
    t.index ["user_id", "action_id"], name: "index_user_actions_on_user_and_action"
    t.index ["user_id"], name: "index_user_actions_on_user_id"
  end

  create_table "user_buildings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "building_id", null: false
    t.integer "level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["building_id"], name: "index_user_buildings_on_building_id"
    t.index ["user_id", "building_id"], name: "index_user_buildings_on_user_and_building"
    t.index ["user_id"], name: "index_user_buildings_on_user_id"
  end

  create_table "user_flags", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "flag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["flag_id"], name: "index_user_flags_on_flag_id"
    t.index ["user_id", "flag_id"], name: "index_user_flags_on_user_id_and_flag_id", unique: true
    t.index ["user_id"], name: "index_user_flags_on_user_id"
  end

  create_table "user_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "quantity", default: 0
    t.string "quality", default: "normal", null: false
    t.index ["item_id"], name: "index_user_items_on_item_id"
    t.index ["user_id", "item_id", "quality"], name: "index_user_items_on_user_item_quality"
    t.index ["user_id"], name: "index_user_items_on_user_id"
  end

  create_table "user_resources", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "resource_id", null: false
    t.integer "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resource_id"], name: "index_user_resources_on_resource_id"
    t.index ["user_id", "resource_id"], name: "index_user_resources_on_user_and_resource"
    t.index ["user_id"], name: "index_user_resources_on_user_id"
  end

  create_table "user_skills", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "skill_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["skill_id"], name: "index_user_skills_on_skill_id"
    t.index ["user_id", "skill_id"], name: "index_user_skills_on_user_and_skill"
    t.index ["user_id"], name: "index_user_skills_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "level", default: 1
    t.integer "experience", default: 0
    t.integer "skill_points", default: 0
    t.boolean "experimental_crafting", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_effects", "effects"
  add_foreign_key "active_effects", "users"
  add_foreign_key "dismantle_yields", "dismantle_rules"
  add_foreign_key "events", "users"
  add_foreign_key "flag_requirements", "flags"
  add_foreign_key "recipe_resources", "recipes"
  add_foreign_key "recipes", "items"
  add_foreign_key "resources", "actions"
  add_foreign_key "unlockables", "flags"
  add_foreign_key "user_actions", "actions"
  add_foreign_key "user_actions", "users"
  add_foreign_key "user_buildings", "buildings"
  add_foreign_key "user_buildings", "users"
  add_foreign_key "user_flags", "flags"
  add_foreign_key "user_flags", "users"
  add_foreign_key "user_items", "items"
  add_foreign_key "user_items", "users"
  add_foreign_key "user_resources", "resources"
  add_foreign_key "user_resources", "users"
  add_foreign_key "user_skills", "skills"
  add_foreign_key "user_skills", "users"
end
