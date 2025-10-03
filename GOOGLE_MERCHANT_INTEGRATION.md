# Google Merchant API Integration

This document describes the Google Merchant API integration for Carbon Cube Kenya.

## Overview

The integration automatically syncs product data from your ads to Google Merchant Center, making your products available in Google Shopping.

## Features

- **Automatic Sync**: Products are automatically synced when created or updated
- **Background Processing**: Uses background jobs to avoid blocking user requests
- **Admin Management**: Admin interface for manual sync operations
- **Validation**: Only valid products are synced to Google Merchant Center

## Setup

### 1. Environment Variables

Add these environment variables to your `.env` file:

```bash
# Google Merchant Center Account ID
GOOGLE_MERCHANT_ACCOUNT_ID=your_account_id

# Google Cloud Project ID
GOOGLE_CLOUD_PROJECT_ID=your_project_id

# Service Account Key File Path
GOOGLE_SERVICE_ACCOUNT_KEY_PATH=/path/to/service-account-key.json

# Enable/disable sync
GOOGLE_MERCHANT_SYNC_ENABLED=true
```

### 2. Google Cloud Setup

1. Create a Google Cloud Project
2. Enable the Content API for Shopping
3. Create a Service Account
4. Download the JSON key file
5. Grant the Service Account access to your Merchant Center account

### 3. Merchant Center Setup

1. Create a data source in Google Merchant Center
2. Set the input method to "API"
3. Note your account ID and data source ID

## Usage

### Automatic Sync

Products are automatically synced when:
- A new ad is created
- An existing ad is updated
- An ad is deleted (removed from Google Merchant Center)

### Manual Sync

Use the admin endpoints for manual operations:

```bash
# Get sync status
GET /admin/google_merchant/status

# Test API connection
GET /admin/google_merchant/test_connection

# Sync all products
POST /admin/google_merchant/sync_all

# Sync specific product
POST /admin/google_merchant/sync_ad/:id

# List all products
GET /admin/google_merchant/ads
```

### Programmatic Usage

```ruby
# Sync a specific ad
ad = Ad.find(123)
ad.sync_to_google_merchant

# Check if ad is valid for sync
ad.valid_for_google_merchant?

# Get Google Merchant data
ad.google_merchant_data
```

## Product Data Mapping

Your existing ad data maps to Google Merchant API as follows:

| Your Field | Google Merchant Field | Notes |
|------------|----------------------|-------|
| `id` | `offerId` | Unique product identifier |
| `title` | `productAttributes.title` | Product title |
| `description` | `productAttributes.description` | Product description |
| `price` | `productAttributes.price` | Price in KES |
| `media[0]` | `productAttributes.imageLink` | First image URL |
| `condition` | `productAttributes.condition` | NEW/USED/REFURBISHED |
| `brand` | `productAttributes.brand` | Product brand |
| Generated URL | `productAttributes.link` | Product page URL |

## Validation Rules

Products are only synced if they meet these criteria:
- Ad is not deleted or flagged
- Seller is active and not blocked
- Ad has valid images
- Title, description, and price are present
- Price is greater than 0

## Background Jobs

The integration uses background jobs to handle API calls:

- `GoogleMerchantSyncJob`: Handles individual product sync
- Automatic retry with exponential backoff
- Error handling and logging

## Monitoring

Check the logs for sync status:
- Successful syncs are logged as INFO
- Failed syncs are logged as ERROR
- Use admin endpoints to monitor sync status

## Troubleshooting

### Common Issues

1. **Authentication Errors**: Check your service account key file
2. **Rate Limiting**: The system includes rate limiting to avoid API limits
3. **Invalid Products**: Check the validation rules above

### Debug Mode

Enable debug logging by setting the log level to DEBUG in your Rails configuration.

## API Endpoints

### Admin Endpoints

- `GET /admin/google_merchant/status` - Get sync status
- `GET /admin/google_merchant/test_connection` - Test API connection
- `GET /admin/google_merchant/ads` - List all products
- `POST /admin/google_merchant/sync_all` - Sync all products
- `POST /admin/google_merchant/sync_ad/:id` - Sync specific product

## Future Enhancements

- Add support for product variants
- Implement product category mapping
- Add bulk operations
- Implement webhook notifications
- Add analytics and reporting
