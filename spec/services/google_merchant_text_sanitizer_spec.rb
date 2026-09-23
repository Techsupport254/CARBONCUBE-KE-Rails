require 'rails_helper'

RSpec.describe GoogleMerchantTextSanitizer do
  describe '.clean_title' do
    it 'removes a promo segment after a separator' do
      expect(described_class.clean_title('6ft Modern TV Stand with Coffee Table – Free Delivery Nairobi'))
        .to eq('6ft Modern TV Stand with Coffee Table')
    end

    it 'removes inline promo phrases' do
      expect(described_class.clean_title('Samsung 55 Inch TV free delivery'))
        .to eq('Samsung 55 Inch TV')
    end

    it 'keeps legitimate suffix segments' do
      expect(described_class.clean_title('Samsung Galaxy S24 Ultra - 256GB Black'))
        .to eq('Samsung Galaxy S24 Ultra - 256GB Black')
    end

    it 'removes phone numbers and call CTAs' do
      expect(described_class.clean_title('Fridge on Sale Call 0712345678'))
        .not_to match(/\d{6,}/)
    end

    it 'removes pay on delivery phrasing' do
      expect(described_class.clean_title('Office Chair – Pay on Delivery'))
        .to eq('Office Chair')
    end

    it 'falls back to the original title if cleaning leaves it too short' do
      expect(described_class.clean_title('iPhone 15 – free delivery countrywide').length)
        .to be >= described_class::MIN_TITLE_LENGTH
    end

    it 'returns blank titles unchanged' do
      expect(described_class.clean_title(nil)).to be_nil
      expect(described_class.clean_title('')).to eq('')
    end
  end

  describe '.clean_description' do
    it 'removes delivery promos, prices and contact info' do
      desc = 'Quality leather sofa. Free delivery within Nairobi. ' \
             'Call/WhatsApp 0712345678. KSh 45,000 only.'
      cleaned = described_class.clean_description(desc)
      expect(cleaned).to include('Quality leather sofa')
      expect(cleaned).not_to match(/free\s+delivery/i)
      expect(cleaned).not_to include('0712')
      expect(cleaned).not_to match(/KSh/i)
    end

    it 'collapses repeated whitespace' do
      expect(described_class.clean_description("Good   product\n\n\n\nDurable and strong"))
        .to eq("Good product\n\nDurable and strong")
    end

    it 'returns blank descriptions unchanged' do
      expect(described_class.clean_description(nil)).to be_nil
    end
  end
end
