class AddClientTokenToSellerVerifications < ActiveRecord::Migration[7.1]
  # Idempotency for the mobile verification queue: the app stages verifications
  # offline and replays them when connectivity returns. A replay after a lost
  # response must not create a duplicate row (or re-fire seller notifications),
  # so each submission carries a client-generated token with a unique index.
  # Postgres unique indexes allow multiple NULLs, so web submissions that don't
  # send the param are unaffected.
  def change
    add_column :seller_verifications, :client_token, :string
    add_index :seller_verifications, :client_token, unique: true
  end
end
