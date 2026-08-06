class AddClaudeUsageToArtefacts < ActiveRecord::Migration[6.1]
  def change
    %i[process_artefacts runbook_artefacts review_artefacts].each do |table|
      change_table table do |t|
        t.integer :input_tokens
        t.integer :cache_creation_input_tokens
        t.integer :cache_read_input_tokens
        t.integer :output_tokens
      end
    end
  end
end
