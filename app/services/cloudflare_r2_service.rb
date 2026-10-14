# frozen_string_literal: true

require 'net/http'
require 'openssl'
require 'digest'
require 'time'
require 'cgi'
require 'securerandom'

class CloudflareR2Service
  DEFAULT_ACCOUNT_ID = '19a90b1197c3c02c78fd4eca7667c64e'
  DEFAULT_BUCKET = 'carbon-docs'

  def self.account_id
    ENV['R2_ACCOUNT_ID'].presence || DEFAULT_ACCOUNT_ID
  end

  def self.bucket
    ENV['R2_BUCKET'].presence || DEFAULT_BUCKET
  end

  def self.access_key_id
    ENV['R2_ACCESS_KEY_ID'].presence || '5750f35baa01a646efd579b59f11f1f9'
  end

  def self.secret_access_key
    ENV['R2_SECRET_ACCESS_KEY'].presence || '0adbd3d547dc4b6dd9e6d80c7caca0980a3ae2a7c36772c3c86a2666461f1186'
  end

  def self.public_url_base
    ENV['R2_PUBLIC_URL'].presence
  end

  def self.host
    "#{account_id}.r2.cloudflarestorage.com"
  end

  # Upload a document to Cloudflare R2
  # data: raw binary string or IO object
  # filename: original filename, e.g. "Geita Investment Catalogue.pdf"
  # content_type: MIME type, e.g. "application/pdf"
  # folder: folder key prefix in the bucket
  # Returns: download URL (public URL or presigned GET URL)
  def self.upload(data, filename, content_type: nil, folder: 'whatsapp_docs')
    return nil if data.blank?

    safe_filename = filename.present? ? File.basename(filename).gsub(/[^\w.-]+/, '_') : 'document.bin'
    unique_key = "#{folder}/#{Time.now.utc.strftime('%Y%m%d')}_#{SecureRandom.hex(4)}_#{safe_filename}"

    mime = content_type.presence || mime_for_filename(safe_filename)

    payload = data.is_a?(String) ? data : data.read
    payload_hash = Digest::SHA256.hexdigest(payload)

    now = Time.now.utc
    amzdate = now.strftime('%Y%m%dT%H%M%SZ')
    datestamp = now.strftime('%Y%m%d')

    canonical_uri = "/#{bucket}/#{unique_key}"
    canonical_headers = "content-type:#{mime}\nhost:#{host}\nx-amz-content-sha256:#{payload_hash}\nx-amz-date:#{amzdate}\n"
    signed_headers = 'content-type;host;x-amz-content-sha256;x-amz-date'

    canonical_request = "PUT\n#{canonical_uri}\n\n#{canonical_headers}\n#{signed_headers}\n#{payload_hash}"
    credential_scope = "#{datestamp}/auto/s3/aws4_request"
    string_to_sign = "AWS4-HMAC-SHA256\n#{amzdate}\n#{credential_scope}\n#{Digest::SHA256.hexdigest(canonical_request)}"

    k_signing = get_signing_key(secret_access_key, datestamp, 'auto', 's3')
    signature = OpenSSL::HMAC.hexdigest('sha256', k_signing, string_to_sign)

    auth_header = "AWS4-HMAC-SHA256 Credential=#{access_key_id}/#{credential_scope}, SignedHeaders=#{signed_headers}, Signature=#{signature}"

    uri = URI("https://#{host}#{canonical_uri}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Put.new(uri)
    req['Host'] = host
    req['Content-Type'] = mime
    req['x-amz-date'] = amzdate
    req['x-amz-content-sha256'] = payload_hash
    req['Authorization'] = auth_header
    req.body = payload

    res = http.request(req)

    unless res.code.to_i == 200
      Rails.logger.error "[CloudflareR2Service] Upload failed for #{unique_key}: HTTP #{res.code} - #{res.body}"
      return nil
    end

    Rails.logger.info "[CloudflareR2Service] Successfully uploaded #{unique_key} (#{payload.bytesize} bytes)"

    # Return public URL if configured, otherwise presigned download URL
    if public_url_base.present?
      "#{public_url_base.chomp('/')}/#{unique_key}"
    else
      presigned_get_url(unique_key)
    end
  rescue StandardError => e
    Rails.logger.error "[CloudflareR2Service] Upload error: #{e.class} - #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    nil
  end

  # Generate a presigned GET URL for downloading an object
  # expires_in: seconds (max 604800 = 7 days for SigV4)
  def self.presigned_get_url(key, expires_in: 604_800)
    now = Time.now.utc
    amzdate = now.strftime('%Y%m%dT%H%M%SZ')
    datestamp = now.strftime('%Y%m%d')

    credential_scope = "#{datestamp}/auto/s3/aws4_request"
    canonical_uri = "/#{bucket}/#{key}"

    query_params = {
      'X-Amz-Algorithm' => 'AWS4-HMAC-SHA256',
      'X-Amz-Credential' => "#{access_key_id}/#{credential_scope}",
      'X-Amz-Date' => amzdate,
      'X-Amz-Expires' => expires_in.to_s,
      'X-Amz-SignedHeaders' => 'host'
    }

    canonical_querystring = query_params.sort.map { |k, v| "#{CGI.escape(k)}=#{CGI.escape(v)}" }.join('&')
    canonical_headers = "host:#{host}\n"
    signed_headers = 'host'
    payload_hash = 'UNSIGNED-PAYLOAD'

    canonical_request = "GET\n#{canonical_uri}\n#{canonical_querystring}\n#{canonical_headers}\n#{signed_headers}\n#{payload_hash}"
    string_to_sign = "AWS4-HMAC-SHA256\n#{amzdate}\n#{credential_scope}\n#{Digest::SHA256.hexdigest(canonical_request)}"

    k_signing = get_signing_key(secret_access_key, datestamp, 'auto', 's3')
    signature = OpenSSL::HMAC.hexdigest('sha256', k_signing, string_to_sign)

    "https://#{host}#{canonical_uri}?#{canonical_querystring}&X-Amz-Signature=#{signature}"
  end

  def self.mime_for_filename(filename)
    ext = File.extname(filename.to_s).downcase
    case ext
    when '.pdf' then 'application/pdf'
    when '.doc' then 'application/msword'
    when '.docx' then 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    when '.xls' then 'application/vnd.ms-excel'
    when '.xlsx' then 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    when '.ppt' then 'application/vnd.ms-powerpoint'
    when '.pptx' then 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
    when '.csv' then 'text/csv'
    when '.txt' then 'text/plain'
    when '.zip' then 'application/zip'
    when '.rar' then 'application/x-rar-compressed'
    else 'application/octet-stream'
    end
  end

  def self.hmac_sha256(key, data)
    OpenSSL::HMAC.digest('sha256', key, data)
  end

  def self.get_signing_key(key, date_stamp, region_name, service_name)
    k_date = hmac_sha256("AWS4#{key}", date_stamp)
    k_region = hmac_sha256(k_date, region_name)
    k_service = hmac_sha256(k_region, service_name)
    hmac_sha256(k_service, 'aws4_request')
  end
end
