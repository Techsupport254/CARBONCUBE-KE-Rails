# app/models/document_type.rb
class DocumentType < ApplicationRecord
  has_many :sellers
end