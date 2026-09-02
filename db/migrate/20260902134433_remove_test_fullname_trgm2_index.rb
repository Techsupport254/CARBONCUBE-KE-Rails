class RemoveTestFullnameTrgm2Index < ActiveRecord::Migration[7.1]
  def up
    remove_index :buyers, name: 'test_fullname_trgm2', if_exists: true
  end
end
