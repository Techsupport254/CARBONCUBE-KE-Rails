class AddCallSourceToCallRecords < ActiveRecord::Migration[7.1]
  def change
    add_column :call_records, :call_source, :string
  end
end
