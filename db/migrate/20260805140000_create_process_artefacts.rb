class CreateProcessArtefacts < ActiveRecord::Migration[6.1]
  def change
    create_table :process_artefacts do |t|
      t.references :incident, null: false, foreign_key: true
      t.string :severity_guess, null: false
      t.text :severity_reasoning, null: false
      t.text :immediate_actions, null: false
      t.text :communication_actions, null: false
      t.text :escalation_path, null: false
      t.timestamps
    end
  end
end
