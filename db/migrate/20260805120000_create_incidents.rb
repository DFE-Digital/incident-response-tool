class CreateIncidents < ActiveRecord::Migration[6.1]
  def change
    create_table :incidents do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.string :service, null: false
      t.string :status, null: false, default: "open"

      t.timestamps
    end
  end
end
