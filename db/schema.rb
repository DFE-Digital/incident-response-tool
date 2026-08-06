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

ActiveRecord::Schema.define(version: 2026_08_06_110000) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "incidents", force: :cascade do |t|
    t.string "title", null: false
    t.text "description", null: false
    t.string "service", null: false
    t.string "status", default: "open", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "teams_thread_id"
  end

  create_table "process_artefacts", force: :cascade do |t|
    t.bigint "incident_id", null: false
    t.string "severity_guess", null: false
    t.text "severity_reasoning", null: false
    t.text "immediate_actions", null: false
    t.text "communication_actions", null: false
    t.text "escalation_path", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "input_tokens"
    t.integer "cache_creation_input_tokens"
    t.integer "cache_read_input_tokens"
    t.integer "output_tokens"
    t.index ["incident_id"], name: "index_process_artefacts_on_incident_id"
  end

  create_table "review_artefacts", force: :cascade do |t|
    t.bigint "incident_id", null: false
    t.datetime "end_datetime", null: false
    t.string "technical_lead"
    t.string "comms_lead"
    t.string "support_lead"
    t.text "timeline_notes"
    t.text "resolution_notes"
    t.text "user_impact"
    t.text "root_cause"
    t.text "timeline", default: "[]", null: false
    t.text "alerted_quickly"
    t.text "diagnosed_and_fixed_quickly"
    t.text "how_we_solved_it"
    t.text "process_and_comms"
    t.text "prevent_recurrence", default: "[]", null: false
    t.text "improve_response", default: "[]", null: false
    t.text "improve_process_comms", default: "[]", null: false
    t.text "runbook_diff"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "input_tokens"
    t.integer "cache_creation_input_tokens"
    t.integer "cache_read_input_tokens"
    t.integer "output_tokens"
    t.index ["incident_id"], name: "index_review_artefacts_on_incident_id"
  end

  create_table "runbook_artefacts", force: :cascade do |t|
    t.bigint "incident_id", null: false
    t.string "match_type", null: false
    t.string "runbook_id"
    t.string "cited_section"
    t.text "general_guidance"
    t.text "steps", default: "[]", null: false
    t.string "owner_to_escalate_to", null: false
    t.text "refusal_reason"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "input_tokens"
    t.integer "cache_creation_input_tokens"
    t.integer "cache_read_input_tokens"
    t.integer "output_tokens"
    t.index ["incident_id"], name: "index_runbook_artefacts_on_incident_id"
  end

  add_foreign_key "process_artefacts", "incidents"
  add_foreign_key "review_artefacts", "incidents"
  add_foreign_key "runbook_artefacts", "incidents"
end
