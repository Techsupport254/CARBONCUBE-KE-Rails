# app/controllers/document_types_controller.rb
class DocumentTypesController < ApplicationController
  def index
    document_types = DocumentType.all
    render json: document_types
  end
end
