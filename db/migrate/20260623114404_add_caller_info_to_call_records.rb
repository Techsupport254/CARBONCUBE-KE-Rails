class AddCallerInfoToCallRecords < ActiveRecord::Migration[7.1]
  def change
    add_column :call_records, :caller_name, :string
    add_column :call_records, :caller_phone, :string
  end
end
