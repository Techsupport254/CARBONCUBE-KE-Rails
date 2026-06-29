class AddEnhancedFieldsToCallRecords < ActiveRecord::Migration[7.1]
  def change
    add_column :call_records, :issue_category, :string
    add_column :call_records, :disposition, :string
    add_column :call_records, :issue_resolved, :boolean
    add_column :call_records, :agent_notes, :text
    add_column :call_records, :follow_up_required, :boolean
    add_column :call_records, :follow_up_date, :date
    add_column :call_records, :follow_up_action, :string
  end
end
