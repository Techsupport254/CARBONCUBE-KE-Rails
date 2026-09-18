# frozen_string_literal: true

# Shared attribution helpers for records a staff member can act on. The actor
# may be a SalesUser (field rep) or an Admin (admin portal). `sales_user`
# associations and sales_user_id columns are typed to SalesUser, so an Admin
# actor must never be assigned to them — the admin is recorded in the
# `actor_name` string column instead.
module ActorAttribution
  extend ActiveSupport::Concern

  private

  # The actor only when they're a sales rep — safe to assign to a
  # `sales_user` association / sales_user_id column. Nil for Admin actors.
  def sales_user_for(actor)
    actor if actor.is_a?(SalesUser)
  end

  # Best available display name for agent_name/actor_name attribution —
  # works for SalesUser, Admin, and any future staff actor type.
  def actor_name_for(actor)
    return unless actor

    actor.try(:fullname).presence || actor.try(:name).presence ||
      actor.try(:username).presence || actor.try(:email).presence
  end
end
