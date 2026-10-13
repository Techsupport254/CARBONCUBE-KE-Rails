class CreateAppInstallNudgeCampaigns < ActiveRecord::Migration[7.1]
  # Tracks the full lifecycle of the "install the app" email campaign for each user.
  # One row per user. The job advances status and next_send_at after each send,
  # and sets status = 'completed' the moment a DeviceToken appears for that user.
  #
  # Statuses:
  #   enrolled   – user is eligible; first email not yet sent
  #   active     – at least one email sent; more reminders may follow
  #   completed  – user installed the app (DeviceToken detected) — no more emails
  #   exhausted  – MAX_SENDS reached without installation — no more emails
  #   suppressed – manually opted out or admin-suppressed
  def change
    create_table :app_install_nudge_campaigns do |t|
      # Polymorphic user reference (Buyer or Seller)
      t.string  :user_type,      null: false
      t.uuid    :user_id,        null: false

      t.string  :status,         null: false, default: 'enrolled'
      t.integer :sends_count,    null: false, default: 0
      t.datetime :next_send_at,  null: false   # when the next email is due
      t.datetime :last_sent_at               # when the most recent email went out
      t.datetime :completed_at              # when the user installed the app

      t.timestamps
    end

    # One campaign record per user, ever.
    add_index :app_install_nudge_campaigns, [:user_type, :user_id],
              unique: true,
              name: 'index_app_install_nudge_campaigns_on_user'

    # The job queries by status + next_send_at — this is the hot path.
    add_index :app_install_nudge_campaigns, [:status, :next_send_at],
              name: 'index_app_install_nudge_campaigns_on_status_and_next_send_at'
  end
end
