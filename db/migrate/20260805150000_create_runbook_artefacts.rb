class CreateRunbookArtefacts < ActiveRecord::Migration[6.1]
  def change
    create_table :runbook_artefacts do |t|
      t.references :incident, null: false, foreign_key: true
      t.string :match_type, null: false
      t.string :runbook_id
      t.string :cited_section
      t.text :general_guidance
      t.text :steps, null: false, default: "[]"
      t.string :owner_to_escalate_to, null: false
      t.text :refusal_reason
      t.timestamps
    end
  end
end
