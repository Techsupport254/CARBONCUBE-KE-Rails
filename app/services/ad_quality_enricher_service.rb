# frozen_string_literal: true

require 'json'

class AdQualityEnricherService
  class << self
    def enrich!(ad_record)
      new(ad_record).process!
    end

    def enrich_by_id(ad_id)
      ad_record = Ad.find_by(id: ad_id)
      return nil unless ad_record
      enrich!(ad_record)
    end
  end

  def initialize(ad_record)
    @ad = ad_record
  end

  def process!
    return false if @ad.blank? || @ad.deleted?

    matched_enrichment = detect_enrichment
    return false unless matched_enrichment

    apply_enrichment!(matched_enrichment)
  end

  private

  def detect_enrichment
    title_text = @ad.title.to_s.strip
    brand_text = @ad.brand.to_s.strip
    desc_text = @ad.description.to_s.strip
    mfg_text = @ad.manufacturer.to_s.strip
    search_corpus = "#{title_text} #{brand_text} #{mfg_text} #{desc_text}".downcase

    # 1. Vivo Wired Earphones
    if search_corpus.include?('vivo') && (search_corpus.include?('earphone') || search_corpus.include?('headphone') || search_corpus.include?('wired'))
      return {
        title: 'vivo 3.5mm In-Ear Wired Earphones with In-Line HD Microphone',
        brand: 'vivo',
        manufacturer: 'vivo Mobile Communication Co., Ltd.',
        model: 'XE100 / XE160 In-Ear Series',
        category_id: 2,
        subcategory_id: 12,
        specifications: {
          'Brand' => 'vivo',
          'Connector Type' => '3.5mm Gold-Plated Audio Jack',
          'Earphone Design' => 'Ergonomic Half In-Ear Acoustic Shell (EarPods Style)',
          'Microphone' => 'High-Definition In-Line Microphone for Handsfree Calling',
          'In-Line Controls' => 'Single Multi-Function Button (Play/Pause, Call Answer/End)',
          'Audio Drivers' => 'Dynamic Deep Bass Acoustic Drivers with Metal Dust Mesh',
          'Cable Length' => '1.2 Meters Tangle-Resistant TPE Wire',
          'Color' => 'Classic Glossy White',
          'Compatibility' => 'vivo, Samsung, Tecno, Infinix, Oppo, Xiaomi, Laptops & 3.5mm Devices'
        },
        overview: 'Enjoy crisp, zero-latency audio and seamless handsfree calling with genuine vivo 3.5mm In-Ear Wired Earphones. Designed with an ergonomic semi-in-ear acoustic housing that fits comfortably into the ear canal.'
      }
    end

    # 2. JBL / Harman P9 Max Style Over-Ear Headphones
    if (search_corpus.include?('jbl') || search_corpus.include?('harman')) && (search_corpus.include?('p9') || search_corpus.include?('bt harman') || (search_corpus.include?('headphone') && @ad.price.to_f <= 2500))
      return {
        title: 'JBL / Harman P9 Max Style Wireless Over-Ear Bluetooth Headphones (Pure Bass, Spatial Audio)',
        brand: 'JBL',
        manufacturer: 'JBL / Harman International',
        model: 'P9 Max Edition',
        category_id: 2,
        subcategory_id: 12,
        specifications: {
          'Brand' => 'JBL',
          'Model Type' => 'P9 Max Style Wireless Over-Ear Headphones',
          'Sound Quality' => 'JBL Pure Bass Sound with Spatial 3D Audio',
          'Design' => 'Breathable Knit Mesh Canopy & Telescoping Metal Arms',
          'Earcup Construction' => 'Anodized Acoustic Shell with Memory Foam Cushions',
          'Connectivity' => 'Bluetooth 5.1 Wireless + 3.5mm Aux Audio Jack',
          'Inputs' => 'Bluetooth, MicroSD / TF Card MP3 Slot, FM Radio, Aux Input',
          'Controls' => 'Integrated Physical Buttons (Power, Volume, Track & Call Controls)',
          'Battery Life' => 'Up to 10 - 12 Hours Continuous Music Playback',
          'Compatibility' => 'Smartphones, Tablets, Laptops, Smart TVs & Bluetooth Devices'
        },
        overview: 'Experience high-fidelity audio, immersive soundstaging, and supreme comfort with the JBL / Harman P9 Max Style Wireless Over-Ear Headphones. Featuring a breathable mesh canopy headband and deep-cushioned earcups.'
      }
    end

    # 3. Samsung 25W PD Fast Charger (EP-TA800)
    if search_corpus.include?('samsung') && (search_corpus.include?('25w') || search_corpus.include?('pd adapter') || search_corpus.include?('travel adapter'))
      return {
        title: 'Samsung 25W Super Fast Charging USB-C Power Adapter (EP-TA800)',
        brand: 'Samsung',
        manufacturer: 'Samsung Electronics Co., Ltd.',
        model: 'EP-TA800',
        category_id: 2,
        subcategory_id: 12,
        specifications: {
          'Brand' => 'Samsung',
          'Model' => 'EP-TA800',
          'Output Power' => '25W Super Fast Charging (PD 3.0 PPS)',
          'Interface' => 'USB Type-C Port',
          'Input Voltage' => '100-240V ~ 50-60Hz Universal AC Input',
          'Plug Standard' => 'UK 3-Pin Standard Plug',
          'Safety Features' => 'Over-Current, Short-Circuit & Over-Temperature Protection',
          'Compatibility' => 'Samsung Galaxy S-Series, Z Fold/Flip, A-Series, iPhones & Type-C Devices'
        },
        overview: 'Power up your Samsung Galaxy smartphones and tablets at lightning speed with the genuine Samsung 25W Super Fast Charging USB-C Power Adapter (EP-TA800).'
      }
    end

    # 4. Amaya AM-M01 3.1A Micro-USB Cable
    if search_corpus.include?('amaya') && (search_corpus.include?('cable') || search_corpus.include?('am-m01') || search_corpus.include?('usb cable') || search_corpus.include?('micro'))
      return {
        title: 'Amaya AM-M01 3.1A Fast Charging Micro-USB Data Cable (1.2m / 1200mm)',
        brand: 'Amaya',
        manufacturer: 'Amaya Technology Co., Ltd.',
        model: 'AM-M01',
        category_id: 2,
        subcategory_id: 12,
        specifications: {
          'Brand' => 'Amaya',
          'Model' => 'AM-M01',
          'Connector Type' => 'USB-A to Micro-USB',
          'Output Current' => '3.1A Super Fast Charging & High-Speed Data Sync',
          'Cable Length' => '1.2 Meters (1200mm)',
          'Cable Material' => 'Reinforced Tangle-Free Flexible PVC Jacket',
          'Data Transfer' => 'Up to 480 Mbps High-Speed Transmission',
          'Compatibility' => 'Android Phones, Power Banks, Bluetooth Speakers & Micro-USB Devices'
        },
        overview: 'Charge your smartphones, power banks, and portable speakers quickly and reliably with the Amaya AM-M01 3.1A Fast Charging Micro-USB Data Cable.'
      }
    end

    # 5. Amaya AM-04 Wireless Neckband
    if search_corpus.include?('amaya') && (search_corpus.include?('neckband') || search_corpus.include?('am-04') || search_corpus.include?('neck band'))
      return {
        title: 'Amaya AM-04 Sweatproof Sports Wireless Bluetooth Neckband Earphones (120dB Stereo Sound)',
        brand: 'Amaya',
        manufacturer: 'Amaya Technology Co., Ltd.',
        model: 'AM-04 Sports Edition',
        category_id: 2,
        subcategory_id: 12,
        specifications: {
          'Brand' => 'Amaya',
          'Model' => 'AM-04 Sports Edition',
          'Sensitivity' => '120dB High-Sensitivity Dynamic Stereo Sound',
          'Design' => 'Ergonomic Magnetic Neckband with In-Line Remote',
          'Durability' => 'Sweatproof & Splash-Resistant Sports Construction',
          'Controls' => '3-Button In-Line Remote (Volume, Calls & Playback)',
          'Connectivity' => 'Bluetooth 5.0 Wireless Range (Up to 10m)',
          'Compatibility' => 'Universal Android, iOS, PC & Bluetooth Audio Devices'
        },
        overview: 'Elevate your daily workouts and commutes with the Amaya AM-04 Sweatproof Sports Wireless Neckband Earphones, engineered with high-output 120dB drivers and magnetic earbuds.'
      }
    end

    # 6. oraimo Wireless Neckbands
    if search_corpus.include?('oraimo') && (search_corpus.include?('neckband') || search_corpus.include?('necklace') || search_corpus.include?('oeb'))
      return {
        title: 'oraimo Necklace Lite (OEB-311) Wireless Bluetooth Neckband Earphones (30-Hour Playtime)',
        brand: 'oraimo',
        manufacturer: 'oraimo Technology Limited',
        model: 'Necklace Lite (OEB-311)',
        category_id: 2,
        subcategory_id: 12,
        specifications: {
          'Brand' => 'oraimo',
          'Model' => 'Necklace Lite (OEB-311)',
          'Battery Playtime' => 'Up to 30 Hours Continuous Playback',
          'Audio Sound' => 'HeavyBass™ Dual 10mm Dynamic Drivers',
          'Fast Charging' => '10-Minute Charge for 10-Hour Playtime (AniFast™)',
          'Microphone' => 'Environmental Noise Cancellation (ENC) for Clear Calls',
          'Water Resistance' => 'IPX4 Sweatproof & Splash Resistant',
          'Earbuds' => 'Magnetic Snap-Together Lock Housing'
        },
        overview: 'Experience non-stop music and ultra-clear calls with the genuine oraimo Necklace Lite (OEB-311) Wireless Neckband Earphones featuring up to 30 hours of playback.'
      }
    end

    # 7. Generic 3.5mm Earphones (fallback for raw "earphones" / "wired earphones")
    if ['wired earphones', 'earphones', 'wired earphone'].include?(title_text.downcase) && @ad.category_id == 2
      detected_brand = brand_text.present? && !['none', 'others', 'china'].include?(brand_text.downcase) ? brand_text : 'Universal'
      return {
        title: "#{detected_brand} 3.5mm In-Ear Wired Stereo Earphones with Microphone",
        brand: detected_brand,
        manufacturer: "#{detected_brand} Electronics",
        model: 'In-Ear 3.5mm Series',
        category_id: 2,
        subcategory_id: 12,
        specifications: {
          'Brand' => detected_brand,
          'Product Type' => 'In-Ear Wired Stereo Earphones',
          'Connector Type' => '3.5mm Gold-Plated Audio Jack',
          'Microphone' => 'High-Definition In-Line Microphone for Handsfree Calling',
          'Cable Length' => '1.2 Meters Tangle-Resistant TPE Wire',
          'Compatibility' => 'Smartphones, Tablets, Laptops & 3.5mm Audio Devices'
        },
        overview: "Enjoy clear, lag-free audio and handsfree calling with #{detected_brand} 3.5mm In-Ear Wired Stereo Earphones."
      }
    end

    # 8. Smartphone match via DeviceCatalogService
    if @ad.category_id == 2 && (@ad.subcategory_id == 8 || search_corpus.include?('phone') || search_corpus.include?('gb'))
      phone_match = DeviceCatalogService.search(title_text, 'phones', 'computersphonesandaccessories').first
      if phone_match && phone_match['title'].present?
        return {
          title: phone_match['title'],
          brand: phone_match['brand'] || brand_text,
          manufacturer: phone_match['brand'] || brand_text,
          model: phone_match['model'] || phone_match['title'],
          category_id: 2,
          subcategory_id: 8, # Phones
          specifications: phone_match['specifications'] || {},
          overview: "High-quality #{phone_match['title']} available on Carbon Cube Kenya with verified specs and fast delivery."
        }
      end
    end

    # 9. Laptop match via DeviceCatalogService
    if (@ad.category_id == 2 && search_corpus.include?('laptop')) || search_corpus.include?('elitebook') || search_corpus.include?('latitude') || search_corpus.include?('thinkpad') || search_corpus.include?('probook')
      laptop_match = DeviceCatalogService.search(title_text, 'laptops', 'computersphonesandaccessories').first
      if laptop_match && laptop_match['title'].present?
        return {
          title: laptop_match['title'],
          brand: laptop_match['brand'] || brand_text,
          manufacturer: laptop_match['brand'] || brand_text,
          model: laptop_match['model'] || laptop_match['title'],
          category_id: 2,
          subcategory_id: 38, # Laptops
          specifications: laptop_match['specifications'] || {},
          overview: "High-performance #{laptop_match['title']} business laptop engineered for productivity and reliability."
        }
      end
    end

    nil
  end

  def apply_enrichment!(enrichment)
    updates = {}

    updates[:title] = enrichment[:title] if enrichment[:title].present?
    updates[:brand] = enrichment[:brand] if enrichment[:brand].present?
    updates[:manufacturer] = enrichment[:manufacturer] if enrichment[:manufacturer].present?
    updates[:model] = enrichment[:model] if enrichment[:model].present?
    updates[:category_id] = enrichment[:category_id] if enrichment[:category_id].present?
    updates[:subcategory_id] = enrichment[:subcategory_id] if enrichment[:subcategory_id].present?

    if enrichment[:specifications].present? && enrichment[:specifications].is_a?(Hash)
      existing_specs = @ad.specifications.is_a?(Hash) ? @ad.specifications : {}
      updates[:specifications] = existing_specs.merge(enrichment[:specifications])
    end

    # Build clean markdown description
    title = updates[:title] || @ad.title
    overview = enrichment[:overview] || "High-quality **#{title}** available on Carbon Cube Kenya."
    specs_hash = updates[:specifications] || @ad.specifications || {}

    desc = "### #{title}\n\n"
    desc += "### Overview\n#{overview}\n\n"

    if specs_hash.is_a?(Hash) && specs_hash.any?
      desc += "### Key Technical Specifications\n"
      specs_hash.each do |k, v|
        desc += "- **#{k}**: #{v}\n" if v.present?
      end
    end

    updates[:description] = desc

    @ad.update_columns(updates.merge(updated_at: Time.current))
    true
  rescue StandardError => e
    Rails.logger.error "AdQualityEnricherService error for Ad ##{@ad&.id}: #{e.message}"
    false
  end
end
