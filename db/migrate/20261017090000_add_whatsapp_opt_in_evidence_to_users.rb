class AddWhatsappOptInEvidenceToUsers < ActiveRecord::Migration[7.1]
  def change
    change_table :sellers, bulk: true do |t|
      t.datetime :whatsapp_opted_in_at
      t.string :whatsapp_opt_in_source
    end

    change_table :buyers, bulk: true do |t|
      t.datetime :whatsapp_opted_in_at
      t.string :whatsapp_opt_in_source
    end
  end
end
