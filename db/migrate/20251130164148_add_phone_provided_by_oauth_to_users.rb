class AddPhoneProvidedByOauthToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :buyers, :phone_provided_by_oauth, :boolean, default: false
    add_column :sellers, :phone_provided_by_oauth, :boolean, default: false
  end
end
