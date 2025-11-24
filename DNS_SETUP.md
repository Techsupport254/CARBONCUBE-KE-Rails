# WhatsApp Service DNS Setup Guide

## Current Situation

The WhatsApp service is currently configured to use the VPS IP address directly (`188.245.245.79:3002`). While this works, it's not ideal for production because:

1. **IP addresses can change** - If you migrate servers or change hosting, you'd need to update code
2. **Harder to maintain** - Domain names are easier to remember and manage
3. **SSL certificates** - Typically tied to domain names, not IPs
4. **Professional appearance** - Domain names look more professional

## Recommended Solution: Set Up DNS

### Option 1: Subdomain (Recommended)

Create a DNS A record for `whatsapp.carboncube-ke.com` pointing to `188.245.245.79`:

```
Type: A
Name: whatsapp
Value: 188.245.245.79
TTL: 3600 (or default)
```

### Option 2: Use Existing Domain

If you have `carboncube-ke.com` already configured, you can use a different port or path:

- `http://carboncube-ke.com:3002` (if firewall allows)
- Or set up nginx reverse proxy: `https://whatsapp.carboncube-ke.com` → `http://localhost:3002`

## After DNS Setup

1. **Update `.env` file:**

   ```bash
   WHATSAPP_SERVICE_URL=http://whatsapp.carboncube-ke.com:3002
   ```

2. **The service will automatically:**
   - Try to resolve the domain
   - Fall back to IP (`188.245.245.79:3002`) if domain doesn't resolve
   - This ensures zero downtime during DNS propagation

## Testing DNS

After setting up DNS, test with:

```bash
nslookup whatsapp.carboncube-ke.com
# Should return: 188.245.245.79

# Or test from Rails console:
rails runner "puts WhatsAppNotificationService.get_service_url"
```

## Current Fallback Behavior

The `WhatsAppNotificationService` already includes smart fallback logic:

- ✅ Tries domain first (if configured)
- ✅ Automatically falls back to IP if domain doesn't resolve
- ✅ Works seamlessly in both development and production

## Next Steps

1. **Set up DNS A record** in your domain registrar (Namecheap, GoDaddy, etc.)
2. **Wait for DNS propagation** (usually 5-60 minutes)
3. **Update `.env`** to use domain instead of IP
4. **Restart Rails server** to pick up new configuration
5. **Verify** the service is using the domain correctly
