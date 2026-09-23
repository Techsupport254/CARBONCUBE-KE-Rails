# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ad, type: :model do
  let(:ad) do
    described_class.new(
      title: 'Test product',
      description: 'A test product description',
      brand: 'TestBrand',
      manufacturer: 'TestMfg',
      price: 100,
      weight_unit: 'Grams',
      condition: :brand_new,
      seller: Seller.new,
      category: Category.new(name: 'Phones'),
      subcategory: Subcategory.new(name: 'Smartphones')
    )
  end

  describe 'inventory validations' do
    it 'is valid when sku, units_per_pack and stock_quantity are nil' do
      expect(ad).to be_valid
    end

    it 'accepts a sku up to 64 characters' do
      ad.sku = 'A' * 64
      ad.valid?
      expect(ad.errors[:sku]).to be_empty
    end

    it 'rejects a sku longer than 64 characters' do
      ad.sku = 'A' * 65
      ad.valid?
      expect(ad.errors[:sku]).to be_present
    end

    it 'rejects a non-positive units_per_pack' do
      ad.units_per_pack = 0
      ad.valid?
      expect(ad.errors[:units_per_pack]).to be_present
    end

    it 'rejects a non-integer units_per_pack' do
      ad.units_per_pack = 2.5
      ad.valid?
      expect(ad.errors[:units_per_pack]).to be_present
    end

    it 'accepts a positive units_per_pack' do
      ad.units_per_pack = 12
      ad.valid?
      expect(ad.errors[:units_per_pack]).to be_empty
    end

    it 'rejects a negative stock_quantity' do
      ad.stock_quantity = -1
      ad.valid?
      expect(ad.errors[:stock_quantity]).to be_present
    end

    it 'accepts a zero stock_quantity (tracked, out of stock)' do
      ad.stock_quantity = 0
      ad.valid?
      expect(ad.errors[:stock_quantity]).to be_empty
    end
  end

  describe '#stock_tracked?' do
    it 'is false when stock_quantity is nil' do
      expect(described_class.new(stock_quantity: nil).stock_tracked?).to be(false)
    end

    it 'is true when stock_quantity is set' do
      expect(described_class.new(stock_quantity: 0).stock_tracked?).to be(true)
    end
  end

  describe '#in_stock?' do
    it 'is true when stock is not tracked' do
      expect(described_class.new(stock_quantity: nil).in_stock?).to be(true)
    end

    it 'is true when tracked stock is positive' do
      expect(described_class.new(stock_quantity: 3).in_stock?).to be(true)
    end

    it 'is false when tracked stock is zero' do
      expect(described_class.new(stock_quantity: 0).in_stock?).to be(false)
    end
  end

  describe '#adjust_stock!' do
    it 'adds the delta to the current stock_quantity' do
      tracked = described_class.new(stock_quantity: 5)
      allow(tracked).to receive(:update).with(stock_quantity: 8).and_return(true)
      expect(tracked.adjust_stock!(3)).to be(true)
    end

    it 'treats nil stock_quantity as zero' do
      tracked = described_class.new(stock_quantity: nil)
      allow(tracked).to receive(:update).with(stock_quantity: 7).and_return(true)
      expect(tracked.adjust_stock!(7)).to be(true)
    end

    it 'returns false and adds an error when the result would be negative' do
      tracked = described_class.new(stock_quantity: 2)
      expect(tracked.adjust_stock!(-5)).to be(false)
      expect(tracked.errors[:stock_quantity]).to be_present
    end
  end

  describe '#google_merchant_policy_excluded?' do
    it 'excludes ads in the Services category' do
      ad.category = Category.new(name: 'Services')
      expect(ad.google_merchant_policy_excluded?).to be(true)
    end

    it 'excludes vehicle categories' do
      ad.category = Category.new(name: 'Vehicles')
      ad.subcategory = nil
      expect(ad.google_merchant_policy_excluded?).to be(true)
    end

    it 'excludes hire/rental titles like "Lorry for Hire Tata"' do
      ad.title = 'Lorry for Hire Tata'
      expect(ad.google_merchant_policy_excluded?).to be(true)
    end

    it 'excludes vehicle-for-sale titles' do
      ad.title = 'Toyota Probox for sale'
      expect(ad.google_merchant_policy_excluded?).to be(true)
    end

    it 'keeps ordinary product ads' do
      expect(ad.google_merchant_policy_excluded?).to be(false)
    end

    it 'keeps vehicle parts and accessories' do
      ad.title = 'Truck side mirror for Isuzu FRR'
      expect(ad.google_merchant_policy_excluded?).to be(false)
    end
  end

  describe '#availability_status' do
    it "returns 'IN_STOCK' when stock is not tracked" do
      expect(described_class.new(stock_quantity: nil).availability_status).to eq('IN_STOCK')
    end

    it "returns 'IN_STOCK' when tracked stock is positive" do
      expect(described_class.new(stock_quantity: 4).availability_status).to eq('IN_STOCK')
    end

    it "returns 'OUT_OF_STOCK' when tracked stock reaches zero" do
      expect(described_class.new(stock_quantity: 0).availability_status).to eq('OUT_OF_STOCK')
    end
  end
end
