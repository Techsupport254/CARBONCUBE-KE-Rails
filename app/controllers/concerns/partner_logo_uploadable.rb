# frozen_string_literal: true

# Shared partner-logo upload — the same handle_upload/process_and_upload_*
# pattern the profile/branch/ad controllers use, extracted once so the partner
# controllers don't each duplicate it. The logo file rides inside the normal
# create/update multipart request (field: logo); callers merge the returned
# secure_url into the record's logo_url.
module PartnerLogoUploadable
  extend ActiveSupport::Concern

  ALLOWED_LOGO_TYPES = %w[image/png image/jpeg image/webp image/svg+xml image/gif].freeze
  MAX_LOGO_SIZE = 5.megabytes
  LOGO_ERROR = 'Logo must be a PNG, JPG, WebP, GIF or SVG image under 5 MB'

  private

  # Returns the Cloudinary secure_url, or nil when the file is unusable.
  def upload_partner_logo(file)
    return nil unless file.respond_to?(:tempfile)
    return nil unless ALLOWED_LOGO_TYPES.include?(file.content_type)
    return nil if file.size > MAX_LOGO_SIZE

    uploaded = Cloudinary::Uploader.upload(
      file.tempfile.path,
      upload_preset: ENV['UPLOAD_PRESET'],
      folder: 'partner_logos'
    )
    uploaded['secure_url']
  rescue => e
    Rails.logger.error "Partner logo upload failed: #{e.message}"
    nil
  end

  # Uploads params[:logo] when present. Returns { logo_url: url } to merge into
  # the update attrs, {} when no file was sent, or :error on failure.
  def partner_logo_attrs
    return {} if params[:logo].blank?

    url = upload_partner_logo(params[:logo])
    url ? { logo_url: url } : :error
  end
end
