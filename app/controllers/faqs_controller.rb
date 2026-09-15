class FaqsController < ApplicationController
  # GET /faqs
  def index
    faqs = Faq.ordered
    faqs = faqs.where(category: params[:category]) if params[:category].present?

    if params[:q].present?
      term = "%#{params[:q].to_s.downcase}%"
      faqs = faqs.where("LOWER(question) LIKE :term OR LOWER(answer) LIKE :term", term: term)
    end

    render json: {
      faqs: faqs.map { |faq| faq_json(faq) },
      meta: { categories: Faq::CATEGORIES }
    }
  end

  # POST /faqs/:id/helpful
  def helpful
    faq = Faq.find(params[:id])

    case params[:value].to_s
    when "yes"
      faq.increment!(:helpful_count)
    when "no"
      faq.increment!(:not_helpful_count)
    else
      return render json: { error: "Invalid value" }, status: :unprocessable_entity
    end

    render json: { faq: faq_json(faq) }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "FAQ not found" }, status: :not_found
  end

  private

  def faq_json(faq)
    {
      id: faq.id,
      question: faq.question,
      answer: faq.answer,
      category: faq.category,
      helpful_count: faq.helpful_count,
      not_helpful_count: faq.not_helpful_count,
      updated_at: faq.updated_at
    }
  end
end
