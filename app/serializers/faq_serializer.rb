class FaqSerializer < ActiveModel::Serializer
  attributes :id, :question, :answer, :category, :position, :helpful_count, :not_helpful_count
end
