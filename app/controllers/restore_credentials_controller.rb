# frozen_string_literal: true

class RestoreCredentialsController < ApplicationController
  RESTORE_CHALLENGE_TTL = 5.minutes

  before_action :authenticate_request, only: %i[create_options create]

  def create_options
    user = current_user
    options = WebAuthn::Credential.options_for_create(
      user: {
        id: WebAuthn.configuration.encoder.encode(user.id.to_s),
        name: user.email,
        display_name: display_name_for(user)
      },
      authenticator_selection: {
        authenticator_attachment: 'platform',
        resident_key: 'required',
        user_verification: 'required'
      },
      attestation: 'none'
    )

    store_restore_challenge(options.challenge)
    render json: options
  end

  def create
    user = current_user
    encoded_challenge = params[:challenge]

    unless restore_challenge_valid?(encoded_challenge)
      render json: { error: 'Invalid or expired challenge' }, status: :bad_request
      return
    end

    begin
      webauthn_credential = WebAuthn::Credential.from_create(
        params[:credential],
        relying_party: WebAuthn.configuration.relying_party
      )

      if webauthn_credential.verify(encoded_challenge)
        RestoreCredential.where(user: user).destroy_all
        RestoreCredential.create!(
          user: user,
          credential_id: webauthn_credential.id,
          public_key: webauthn_credential.public_key,
          sign_count: webauthn_credential.sign_count
        )
        render json: { success: true }, status: :ok
      else
        render json: { error: 'Credential verification failed' }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "Restore credential creation failed: #{e.message}"
      render json: { error: 'Invalid credential' }, status: :unprocessable_entity
    end
  end

  def signin_options
    options = WebAuthn::Credential.options_for_get(
      user_verification: 'required',
      allow_credentials: []
    )

    store_restore_challenge(options.challenge)
    render json: options
  end

  def signin
    encoded_challenge = params[:challenge]

    unless restore_challenge_valid?(encoded_challenge)
      render json: { error: 'Invalid or expired challenge' }, status: :bad_request
      return
    end

    begin
      webauthn_credential = WebAuthn::Credential.from_get(
        params[:credential],
        relying_party: WebAuthn.configuration.relying_party
      )

      stored_credential = RestoreCredential.find_by(credential_id: webauthn_credential.id)

      unless stored_credential
        render json: { error: 'Unknown credential' }, status: :unauthorized
        return
      end

      if webauthn_credential.verify(
        encoded_challenge,
        public_key: stored_credential.public_key,
        sign_count: stored_credential.sign_count
      )
        stored_credential.update!(sign_count: webauthn_credential.sign_count)
        user = stored_credential.user
        role = user.class.name.downcase
        token = JsonWebToken.encode(user_id: user.id, email: user.email, role: role)

        render json: {
          token: token,
          user: {
            id: user.id,
            email: user.email,
            role: role,
            name: display_name_for(user)
          }
        }, status: :ok
      else
        render json: { error: 'Credential verification failed' }, status: :unauthorized
      end
    rescue StandardError => e
      Rails.logger.error "Restore credential sign-in failed: #{e.message}"
      render json: { error: 'Invalid credential' }, status: :unauthorized
    end
  end

  private

  def display_name_for(user)
    if user.respond_to?(:fullname) && user.fullname.present?
      user.fullname
    elsif user.respond_to?(:username) && user.username.present?
      user.username
    else
      user.email
    end
  end

  def store_restore_challenge(challenge)
    Rails.cache.write(restore_challenge_key(challenge), true, expires_in: RESTORE_CHALLENGE_TTL)
  end

  def restore_challenge_valid?(challenge)
    challenge.present? && Rails.cache.exist?(restore_challenge_key(challenge))
  end

  def restore_challenge_key(challenge)
    "webauthn_restore_challenge_#{challenge}"
  end
end
