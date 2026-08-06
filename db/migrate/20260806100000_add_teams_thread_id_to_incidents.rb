class AddTeamsThreadIdToIncidents < ActiveRecord::Migration[6.1]
  def change
    add_column :incidents, :teams_thread_id, :string
  end
end
