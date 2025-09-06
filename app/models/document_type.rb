# app/models/document_type.rb
class DocumentType < ApplicationRecord
  has_many :sellers
  has_many :seller_documents, dependent: :destroy
end