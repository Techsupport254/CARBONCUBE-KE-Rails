class Category < ApplicationRecord
    has_and_belongs_to_many :sellers
    has_many :subcategories, dependent: :destroy
    has_many :ads, dependent: :nullify
    has_many :categories_sellers
    has_many :sellers, through: :categories_sellers
    accepts_nested_attributes_for :subcategories

    validates :name, presence: true
end
