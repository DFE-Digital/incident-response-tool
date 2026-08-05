class CreateReviewArtefacts < ActiveRecord::Migration[6.1]
  def change
    create_table :review_artefacts do |t|
      t.references :incident, null: false, foreign_key: true

      # User-provided on the "Mark resolved" form
      t.datetime :end_datetime, null: false
      t.string :technical_lead
      t.string :comms_lead
      t.string :support_lead
      t.text :timeline_notes
      t.text :resolution_notes

      # Claude-generated review fields (DfE template shape)
      t.text :user_impact
      t.text :root_cause
      t.text :timeline, null: false, default: "[]"
      t.text :alerted_quickly
      t.text :diagnosed_and_fixed_quickly
      t.text :how_we_solved_it
      t.text :process_and_comms
      t.text :prevent_recurrence, null: false, default: "[]"
      t.text :improve_response, null: false, default: "[]"
      t.text :improve_process_comms, null: false, default: "[]"
      t.text :runbook_diff

      t.timestamps
    end
  end
end
