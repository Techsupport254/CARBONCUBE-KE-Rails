# frozen_string_literal: true

# Called by the mobile app to check whether the native App Store / Play Store
# review dialog should be triggered, and to report when it has been shown.
#
# Routes:
#   GET  /app_store_review_prompt        → index (should_prompt?)
#   POST /app_store_review_prompt/mark_shown → mark_shown
class AppStoreReviewPromptController < ApplicationController
  before_action :authenticate_request

  # GET /app_store_review_prompt
  # Returns { should_prompt: true|false }
  def index
    prompt = AppStoreReviewPrompt.find_by(user: current_user)
    render json: { should_prompt: prompt_ready?(prompt) }
  end

  # POST /app_store_review_prompt/mark_shown
  # The app calls this after successfully requesting the native review dialog.
  def mark_shown
    prompt = AppStoreReviewPrompt.find_by(user: current_user)
    prompt&.mark_shown!
    head :no_content
  end

  private

  # Treat a prompt as "ready" only when it exists and scheduled_at has passed.
  def prompt_ready?(prompt)
    prompt&.status == 'pending' && prompt.scheduled_at <= Time.current
  end
end
