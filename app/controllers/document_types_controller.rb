class DocumentTypesController < ApplicationController
  def index
    document_types = DocumentType.all.order(:name)
    render json: document_types
  end
end