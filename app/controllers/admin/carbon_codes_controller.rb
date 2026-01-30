# frozen_string_literal: true

class Admin::CarbonCodesController < ApplicationController
    before_action :authenticate_admin
    before_action :set_carbon_code, only: [:show, :update, :destroy]

    # GET /admin/carbon_codes
    def index
      codes = CarbonCode.includes(:associable).order(created_at: :desc)

      if params[:associable_type].present?
        codes = codes.where(associable_type: params[:associable_type])
      end
      if params[:associable_id].present?
        codes = codes.where(associable_id: params[:associable_id])
      end
      if params[:active].present?
        codes = codes.active if params[:active] == "true"
      end

      total = codes.count
      page = (params[:page] || 1).to_i
      per_page = [(params[:per_page] || 20).to_i, 100].min
      codes = codes.offset((page - 1) * per_page).limit(per_page) unless params[:all]

      render json: {
        carbon_codes: codes.map { |c| carbon_code_json(c) },
        pagination: params[:all] ? nil : {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: (total.to_f / per_page).ceil
        }
      }
    end

    # GET /admin/carbon_codes/:id
    def show
      render json: carbon_code_json(@carbon_code)
    end

    # POST /admin/carbon_codes
    def create
      @carbon_code = CarbonCode.new(carbon_code_params)
      if @carbon_code.save
        render json: carbon_code_json(@carbon_code), status: :created
      else
        render json: { errors: @carbon_code.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /admin/carbon_codes/:id
    def update
      if @carbon_code.update(carbon_code_params)
        render json: carbon_code_json(@carbon_code)
      else
        render json: { errors: @carbon_code.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /admin/carbon_codes/:id
    def destroy
      @carbon_code.destroy
      head :no_content
    end

    private

    def authenticate_admin
      @current_user = AdminAuthorizeApiRequest.new(request.headers).result
      unless @current_user && @current_user.is_a?(Admin)
        render json: { error: 'Not Authorized' }, status: :unauthorized
      end
    end

    def set_carbon_code
      @carbon_code = CarbonCode.find(params[:id])
    end

    def carbon_code_params
      params.require(:carbon_code).permit(
        :code, :label, :expires_at, :max_uses,
        :associable_type, :associable_id
      )
    end

    def carbon_code_json(c)
      {
        id: c.id,
        code: c.code,
        label: c.label,
        expires_at: c.expires_at&.iso8601,
        max_uses: c.max_uses,
        times_used: c.times_used,
        valid_for_use: c.valid_for_use?,
        associable_type: c.associable_type,
        associable_id: c.associable_id,
        associable: associable_summary(c.associable),
        created_at: c.created_at&.iso8601,
        updated_at: c.updated_at&.iso8601
      }
    end

    def associable_summary(assoc)
      return nil if assoc.blank?
      {
        id: assoc.id,
        type: assoc.class.name,
        email: assoc.respond_to?(:email) ? assoc.email : nil,
        fullname: assoc.respond_to?(:fullname) ? assoc.fullname : nil
      }
    end
  end
