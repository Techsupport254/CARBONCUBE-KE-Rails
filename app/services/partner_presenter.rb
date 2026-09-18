# frozen_string_literal: true

# JSON serialization for the partners feature — shared by the sales partners
# controller, sub-resource controllers, and promote_to_partner endpoints.
module PartnerPresenter
  module_function

  def partner(record)
    activities = record.activities.loaded? ? record.activities : record.activities.to_a
    last_contact = activities.find { |a| PartnerActivity::CONTACT_TYPES.include?(a.activity_type) }
    last_actor = activities.find { |a| a.sales_user_id.present? || a.actor_name.present? }
    {
      id: record.id,
      name: record.name,
      partner_type: record.partner_type,
      status: record.status,
      contact_person: record.contact_person,
      phone: record.phone,
      email: record.email,
      website: record.website,
      location: record.location,
      logo_url: record.logo_url,
      description: record.description,
      signed_on: record.signed_on,
      agreement_notes: record.agreement_notes,
      commission_rate: record.commission_rate,
      notes: record.notes,
      follow_up_date: record.follow_up_date,
      follow_up_note: record.follow_up_note,
      last_contacted_at: record.last_contacted_at,
      sales_user_id: record.sales_user_id,
      agent_name: record.sales_user&.fullname || last_actor&.sales_user&.fullname || last_actor&.actor_name,
      seller_id: record.seller_id,
      seller_name: record.seller&.enterprise_name || record.seller&.fullname,
      seller_slug: record.seller&.slug,
      sales_brand_id: record.sales_brand_id,
      sells_on_platform: record.sells_on_platform?,
      last_activity_notes: last_contact&.notes,
      last_activity_outcome: last_contact&.outcome,
      visits_count: activities.count { |a| a.activity_type == 'visit' },
      calls_count: activities.count { |a| a.activity_type == 'call' },
      activities_count: activities.size,
      distributors_count: record.distributors.size,
      contacts_count: record.contacts.size,
      created_at: record.created_at,
      updated_at: record.updated_at
    }
  end

  def activity(record)
    {
      id: record.id,
      activity_type: record.activity_type,
      occurred_at: record.occurred_at,
      notes: record.notes,
      outcome: record.outcome,
      follow_up_date: record.follow_up_date,
      latitude: record.latitude,
      longitude: record.longitude,
      agent_name: record.sales_user&.fullname || record.actor_name,
      created_at: record.created_at
    }
  end

  def contact(record)
    {
      id: record.id,
      partner_id: record.partner_id,
      name: record.name,
      role_title: record.role_title,
      email: record.email,
      phone: record.phone,
      is_primary: record.is_primary,
      receives_updates: record.receives_updates,
      notes: record.notes,
      created_at: record.created_at
    }
  end

  def distributor(record)
    {
      id: record.id,
      partner_id: record.partner_id,
      name: record.name,
      contact_person: record.contact_person,
      phone: record.phone,
      email: record.email,
      location: record.location,
      territory: record.territory,
      business_type: record.business_type,
      website: record.website,
      logo_url: record.logo_url,
      status: record.status,
      notify_pricing: record.notify_pricing,
      notify_updates: record.notify_updates,
      seller_id: record.seller_id,
      seller_name: record.seller&.enterprise_name || record.seller&.fullname,
      seller_slug: record.seller&.slug,
      agent_name: record.sales_user&.fullname || record.actor_name,
      notes: record.notes,
      pending_invite: invite(record.pending_invite),
      created_at: record.created_at
    }
  end

  def update(record)
    {
      id: record.id,
      kind: record.kind,
      title: record.title,
      body: record.body,
      ad_id: record.ad_id,
      metadata: record.metadata,
      agent_name: record.sales_user&.fullname || record.actor_name,
      created_at: record.created_at
    }
  end

  def invite(record)
    return nil unless record

    {
      id: record.id,
      status: record.status,
      invite_kind: record.invite_kind,
      email: record.email,
      phone: record.phone,
      expires_at: record.expires_at,
      accepted_at: record.accepted_at,
      reminder_count: record.reminder_count,
      invite_sent_at: record.invite_sent_at,
      last_reminded_at: record.last_reminded_at,
      created_at: record.created_at
    }
  end

  def seller(record)
    return nil unless record

    {
      id: record.id,
      fullname: record.fullname,
      enterprise_name: record.enterprise_name,
      slug: record.slug,
      phone_number: record.phone_number,
      email: record.email,
      activated: record.provider != 'partner_invite'
    }
  end
end
