# Seller Email Testing Guide

This guide explains how to test the seller communication email template with seller 114.

## Files Created

1. **Rake Tasks** (`lib/tasks/test_seller_email.rake`)

   - `rails email:test_seller_114` - Queue email job for seller 114
   - `rails email:test_seller_114_now` - Send email immediately
   - `rails email:preview_seller_114` - Generate email preview

2. **Background Job** (`app/jobs/send_seller_communication_job.rb`)

   - Handles email sending in background
   - Includes error handling and logging

3. **Test Scripts**
   - `lib/scripts/test_seller_114_email.rb` - Rails console script
   - `lib/scripts/test_seller_114_cli.rb` - Command line script

## Testing Methods

### Method 1: Rake Tasks (Recommended)

```bash
# Queue email job (background processing)
rails email:test_seller_114

# Send email immediately (for testing)
rails email:test_seller_114_now

# Generate email preview
rails email:preview_seller_114
```

### Method 2: Rails Console

```bash
rails console
load 'lib/scripts/test_seller_114_email.rb'
```

### Method 3: Command Line Script

```bash
ruby lib/scripts/test_seller_114_cli.rb
```

### Method 4: API Endpoint

```bash
curl -X POST http://localhost:3000/api/admin/seller_communications/send_to_test_seller
```

## Job Processing

To process queued jobs:

```bash
# Start job worker
rails jobs:work

# Or in production with Sidekiq/Resque
bundle exec sidekiq
```

## Email Preview

After running the preview task, open:
`tmp/email_preview_seller_114.html`

## Seller 114 Information

The script will display:

- Seller name and email
- Enterprise name
- Location
- Analytics data (if available)

## Error Handling

All scripts include:

- Seller existence validation
- Email generation error handling
- Job queuing error handling
- Detailed error logging

## Production Considerations

- Use job queuing for large-scale email sending
- Monitor job queue for failures
- Implement rate limiting for email sending
- Use proper SMTP configuration
- Consider email delivery tracking
