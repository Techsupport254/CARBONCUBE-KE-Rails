class CreateIncomes < ActiveRecord::Migration[7.1]
  def change
    create_table :incomes do |t|
      t.string :range, null: false
      t.timestamps
    end

    # Add unique index on the 'range' column to enforce uniqueness
    add_index :incomes, :range, unique: true
  end
end
