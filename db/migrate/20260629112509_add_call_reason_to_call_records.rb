class AddCallReasonToCallRecords < ActiveRecord::Migration[7.1]
  def change
    add_column :call_records, :call_reason, :string
  end
end
