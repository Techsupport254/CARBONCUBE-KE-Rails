class AdminSerializer < ActiveModel::Serializer
  attributes :id, :fullname, :username, :email, :provider, :created_at, :updated_at
  # Exclude password_digest and other sensitive data
end
