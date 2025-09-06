class SellerDocumentSerializer < ActiveModel::Serializer
  attributes :id, :document_type_id, :document_url, :document_expiry_date, :document_verified, :created_at, :updated_at

  belongs_to :document_type, serializer: DocumentTypeSerializer
end
