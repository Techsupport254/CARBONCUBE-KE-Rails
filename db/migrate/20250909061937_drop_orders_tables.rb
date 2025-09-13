class DropOrdersTables < ActiveRecord::Migration[7.1]
  def change
    # Drop dependent tables first
    drop_table :shipments, if_exists: true
    
    # Drop order-related tables in reverse dependency order
    drop_table :order_items, if_exists: true
    drop_table :order_sellers, if_exists: true
    drop_table :orders, if_exists: true
    
    # Drop buy_for_me order-related tables
    drop_table :buy_for_me_order_items, if_exists: true
    drop_table :buy_for_me_order_sellers, if_exists: true
    drop_table :buy_for_me_order_cart_items, if_exists: true
    drop_table :buy_for_me_orders, if_exists: true
    
    # Drop any sequences that might exist
    execute "DROP SEQUENCE IF EXISTS order_vendors_id_seq CASCADE;"
    execute "DROP SEQUENCE IF EXISTS buy_for_me_order_vendors_id_seq CASCADE;"
  end
end
