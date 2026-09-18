# frozen_string_literal: true

# Admin-portal users can now act on the /sales/* partner & brand endpoints.
# sales_user_id columns are typed to SalesUser, so an Admin actor is recorded
# in this nullable display-name column instead (shown via agent_name).
class AddActorNameToSalesPartnerAttribution < ActiveRecord::Migration[7.1]
  def change
    add_column :partner_activities, :actor_name, :string
    add_column :sales_brand_activities, :actor_name, :string
    add_column :partner_updates, :actor_name, :string
    add_column :partner_distributors, :actor_name, :string
  end
end
