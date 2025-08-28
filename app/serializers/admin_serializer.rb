class AdminSerializer < ActiveModel::Serializer
  attributes :id, :fullname, :username, :email
  # Exclude password_digest and other sensitive data
end
