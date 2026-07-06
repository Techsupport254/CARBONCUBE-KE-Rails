# WhatsApp Product Creation Feature

## Overview

This feature allows sellers to add products directly from WhatsApp by sending messages to the business WhatsApp number. The system uses a conversational flow to collect product information step-by-step, enhanced with AI-powered intelligence for automatic brand detection, category suggestions, price recommendations, specification fetching, and description generation.

## Architecture

### Components

1. **WhatsappProductSession Model** (`app/models/whatsapp_product_session.rb`)
   - Tracks the state of product creation sessions
   - Stores seller ID, phone number, current step, and product data
   - Manages session lifecycle (pending, completed, cancelled)

2. **WhatsAppProductCreationService** (`app/services/whatsapp_product_creation_service.rb`)
   - Handles the conversational flow for product creation
   - Processes user input at each step
   - Validates input and provides feedback
   - Creates the final product in the database
   - Integrates AI suggestions throughout the flow

3. **WhatsAppAIPrefillService** (`app/services/whatsapp_ai_prefill_service.rb`)
   - Analyzes product titles to detect brands and models
   - Suggests appropriate categories based on product description
   - Provides price recommendations based on market data
   - Fetches specifications for phones/tablets from DeviceCatalogService and GSM Arena
   - Generates intelligent product descriptions

4. **WhatsAppCloudService** (`app/services/whats_app_cloud_service.rb`)
   - Extended to intercept seller messages
   - Routes product creation commands to WhatsAppProductCreationService
   - Sends automated responses back to sellers

5. **WebhooksController** (`app/controllers/webhooks_controller.rb`)
   - Receives WhatsApp webhook events
   - Bypasses signature verification in development mode for testing

## Database Schema

### whatsapp_product_sessions table

```ruby
create_table :whatsapp_product_sessions, id: :uuid do |t|
  t.uuid :seller_id, null: false
  t.string :phone_number, null: false
  t.string :status, default: 'pending', null: false
  t.integer :step, default: 1, null: false
  t.text :product_data
  t.datetime :last_message_at
  t.timestamps
end
```

## User Flow

### Commands

- **ADD** - Start adding a new product
- **CANCEL** - Cancel current product creation
- **HELP** - Show help message
- **ENHANCE** - Use AI-enhanced description (available after description step)
- **KEEP** - Keep original description (available after description step)

### Product Creation Steps with AI Features

1. **Title** (Step 1) - Product title (10-150 characters)
   - 🤖 AI automatically detects brand from title
   - 💡 AI suggests improved title if confidence is high

2. **Description** (Step 2) - Product description (20-5000 characters)
   - 💡 AI generates professional description option
   - User can choose to ENHANCE or KEEP original

3. **Price** (Step 3) - Price in KES (1-1,000,000)
   - 💰 AI shows market data from similar products
   - ⚠️ AI warns if price is significantly above/below market average
   - 💡 AI recommends competitive pricing

4. **Category** (Step 4) - Select from available categories
   - 🤖 AI suggests category based on title if not found
   - Confidence score shown for suggestions

5. **Brand** (Step 5) - Product brand (2+ characters)
   - 🤖 AI auto-fills brand if detected in title step
   - 🤖 AI fetches specifications for phones/tablets automatically

6. **Condition** (Step 6) - Product condition (brand_new, second_hand, refurbished, x_japan, ex_uk)
   - Standard selection from available options

7. **Images** (Step 7) - Upload up to 5 images or skip
   - Standard image upload or skip option

8. **Confirm** (Step 8) - Confirm and create product
   - 📦 Shows product summary
   - 🔗 Provides product link with UTM tracking after creation

## Setup Requirements

### Environment Variables

Add these to your `.env` file:

```bash
# WhatsApp Cloud API Configuration
WHATSAPP_CLOUD_PHONE_NUMBER_ID=your_phone_number_id
WHATSAPP_CLOUD_ACCESS_TOKEN=your_access_token
WHATSAPP_CLOUD_VERIFY_TOKEN=your_verify_token
META_APP_SECRET=your_app_secret
```

### WhatsApp Business Setup

1. Create a Meta Business Account
2. Set up a WhatsApp Business API account
3. Configure the webhook URL: `https://your-domain.com/webhooks/whatsapp`
4. Subscribe to `messages` field
5. Verify the webhook with your verify token

### Database Migration

Run the migration to create the sessions table:

```bash
rails db:migrate
```

## Testing

### Manual Testing with curl

Use the provided test script:

```bash
./test_whatsapp_product_creation.sh
```

This script simulates WhatsApp webhook events to test the complete product creation flow.

### Test Scenarios

The test script covers:
1. Webhook endpoint accessibility
2. ADD command to start product creation
3. Each step of the product creation flow
4. HELP command
5. CANCEL command
6. Error handling for invalid inputs

### Important Notes for Testing

1. **Rails Server**: Must be running on port 3001
2. **Seller Account**: The test phone number (0712345678) must exist in the database
3. **Subscription**: The seller must have an active subscription tier
4. **WhatsApp Credentials**: Required for actual message sending (optional for webhook testing in development)

## AI Features

### Intelligent Brand Detection
- Analyzes product titles to extract brand information
- Uses DeviceCatalogService for phone/tablet brands
- Falls back to common brand keyword matching
- Confidence scoring for suggestions

### Smart Category Suggestions
- Analyzes title and description to suggest appropriate categories
- Uses keyword matching against category names
- Provides confidence scores for suggestions
- Helps users select the right category quickly

### Price Market Intelligence
- Fetches price data from similar products in the database
- Shows price range, average, and recommended price
- Warns if user's price is significantly above/below market
- Helps sellers set competitive pricing

### Specification Fetching
- Automatically fetches specifications for phones/tablets
- Uses DeviceCatalogService for local device data
- Falls back to GSM Arena scraping for detailed specs
- Stores specifications with product data

### AI-Enhanced Descriptions
- Generates professional product descriptions
- Incorporates fetched specifications
- Uses category-aware templates
- Users can choose to accept or keep original

### Product Link Delivery
- Automatically generates product URL after creation
- Includes UTM parameters for tracking (source: whatsapp, medium: product_creation, campaign: whatsapp_ai)
- Enables sellers to share their product links directly
- Tracks engagement from WhatsApp-created products

## Usage Example with AI Features

### Seller Interaction

```
Seller: ADD
System: 🚀 Let's add your product!
        I'll guide you through creating a product listing step by step.
        
        Step 1/8: Please provide a title for your product (minimum 10 characters):
        
        Send 'CANCEL' at any time to stop.

Seller: Samsung Galaxy S21 Ultra 5G
System: ✅ Title saved!
        
        🤖 AI detected brand: Samsung
        
        Now, please provide a description for your product (minimum 20 characters):

Seller: Brand new Samsung Galaxy S21 Ultra 5G with 128GB storage. Comes with original box and accessories. 1 year warranty included.
System: ✅ Description saved!
        
        💡 AI can enhance your description with professional formatting and specifications.
        Reply 'ENHANCE' to use AI description or 'KEEP' to use your original.

Seller: ENHANCE
System: ✅ Description enhanced with AI!
        
        Now, please provide the price in KES (e.g., 5000):

Seller: 85000
System: ✅ Price saved: 85000 KES
        
        💰 Market data for similar products (15 found):
        - Price range: 65000 - 120000 KES
        - Average price: 85000 KES
        - Recommended: 85000 KES
        
        Now, please select a category by number:
        1. Computers Phones and Accessories
        2. Automotive
        ...
        
        Or type the category name:

Seller: phones
System: ✅ Category saved: Computers Phones and Accessories
        
        Now, please provide the brand (e.g., Samsung, Apple, Toyota):

Seller: Samsung
System: ✅ Brand saved: Samsung
        
        🤖 AI fetched product specifications automatically!
        
        Now, please select the condition by number:
        1. Brand new
        2. Second hand
        3. Refurbished
        4. X japan
        5. Ex uk

Seller: 1
System: ✅ Condition saved: Brand new
        
        Now, please send product images (up to 5 images). Send 'SKIP' if you don't have images ready.

Seller: [Sends image]
System: ✅ Image added (1/5). Send more images or 'DONE' to continue.

Seller: DONE
System: Images skipped.
        
        📦 Product Summary
        
        *Title:* Samsung Galaxy S21 Ultra 5G
        *Price:* 85000 KES
        *Brand:* Samsung
        *Condition:* Brand new
        *Category:* Computers Phones and Accessories
        *Images:* 1 image(s)
        
        Reply 'CONFIRM' to create this product or 'CANCEL' to start over.

Seller: CONFIRM
System: 🎉 Product created successfully!
        
        Your product is now live on CarbonCube.
        
        🔗 Product Link: https://carboncube.ke/ads/xyz?utm_source=whatsapp&utm_medium=product_creation&utm_campaign=whatsapp_ai
        
        You can view and manage it from your seller dashboard.
```

## Error Handling

### Validation Errors

- **Title too short/long**: Clear error message with character limits
- **Description too short/long**: Clear error message with character limits
- **Invalid price**: Must be numeric and within range
- **Category not found**: Suggests available categories
- **Invalid condition**: Shows available options
- **Missing subscription**: Prompts user to upgrade account
- **Ad limit reached**: Informs user of tier limits

### Session Management

- Sessions automatically expire after 24 hours of inactivity
- CANCEL command resets the session
- Multiple sessions per seller are prevented
- Sessions are tied to phone numbers for security

## Security Considerations

1. **Webhook Signature Verification**: Enabled in production, bypassed in development
2. **Seller Authentication**: Only registered sellers can create products
3. **Subscription Validation**: Checks for active subscription before allowing product creation
4. **Ad Limits**: Enforces tier-based ad limits
5. **Input Validation**: All user inputs are validated before processing

## Limitations

1. **Image Upload**: Currently supports up to 5 images per product
2. **Category Selection**: Limited to first 10 categories in the list
3. **No Edit Functionality**: Products created via WhatsApp cannot be edited through WhatsApp
4. **Single Product Flow**: Cannot create multiple products simultaneously

## Future Enhancements

1. Support for product editing via WhatsApp
2. Bulk product creation
3. Image optimization and compression
4. Voice message support for product descriptions
5. Multi-language support
6. Product templates for quick creation
7. Integration with inventory management

## Troubleshooting

### Common Issues

**Issue**: Webhook returns 403 Forbidden
- **Solution**: Check webhook signature verification is properly configured in production

**Issue**: "Missing credentials" error
- **Solution**: Ensure WHATSAPP_CLOUD_ACCESS_TOKEN and WHATSAPP_CLOUD_PHONE_NUMBER_ID are set in .env

**Issue**: Seller not found
- **Solution**: Ensure the seller's phone number in WhatsApp matches the database format (07XXXXXXXXX)

**Issue**: Ad limit reached
- **Solution**: Seller needs to upgrade their subscription tier

**Issue**: Product not created
- **Solution**: Check Rails logs for validation errors in the product creation process

## Monitoring

### Logs to Monitor

- `[WhatsAppCloudService]` - WhatsApp message processing
- `[WhatsAppProductCreationService]` - Product creation flow
- `whatsapp_product_sessions` table - Session state and errors

### Key Metrics

- Number of products created via WhatsApp
- Average time to complete product creation
- Drop-off rate at each step
- Error rates by step

## Support

For issues or questions about this feature, contact the development team or check the project documentation.
