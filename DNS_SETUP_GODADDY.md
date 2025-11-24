# DNS Setup Guide for GoDaddy

Your domain `carboncube-ke.com` is managed through **GoDaddy** (nameservers: `ns41.domaincontrol.com`, `ns42.domaincontrol.com`).

## Step-by-Step Instructions

### 1. Log in to GoDaddy

1. Go to [https://www.godaddy.com](https://www.godaddy.com)
2. Click **Sign In** (top right)
3. Enter your GoDaddy account credentials

### 2. Access DNS Management

1. Once logged in, click on **My Products** (or **Domains**)
2. Find `carboncube-ke.com` in your domain list
3. Click on the domain name
4. Click on **DNS** tab (or **Manage DNS**)

### 3. Add A Record for WhatsApp Subdomain

1. Scroll down to the **Records** section
2. Click **Add** button (or **+ Add Record**)
3. Fill in the following:
   - **Type**: Select **A** from dropdown
   - **Name**: Enter `whatsapp` (this creates `whatsapp.carboncube-ke.com`)
   - **Value**: Enter `188.245.245.79` (your VPS IP)
   - **TTL**: Leave as default (usually 600 seconds or 1 hour)
4. Click **Save** (or **Add Record**)

### 4. Verify the Record

After saving, you should see a new record in your DNS list:

```
Type: A
Name: whatsapp
Value: 188.245.245.79
TTL: 600
```

### 5. Wait for DNS Propagation

- DNS changes typically propagate within **5-60 minutes**
- Can take up to 24-48 hours in rare cases
- You can test propagation using:
  ```bash
  nslookup whatsapp.carboncube-ke.com
  # Should return: 188.245.245.79
  ```

### 6. Update Your `.env` File

Once DNS is working, update your `.env` file:

```bash
# Change from:
WHATSAPP_SERVICE_URL=http://188.245.245.79:3002

# To:
WHATSAPP_SERVICE_URL=http://whatsapp.carboncube-ke.com:3002
```

### 7. Restart Rails Server

After updating `.env`, restart your Rails server to pick up the new configuration.

## Visual Guide (GoDaddy Interface)

The DNS management page typically looks like this:

```
┌─────────────────────────────────────────────────┐
│ DNS Management                                   │
├─────────────────────────────────────────────────┤
│                                                  │
│ Records                                          │
│ ┌─────────┬──────────┬──────────────────────┐  │
│ │ Type    │ Name     │ Value                │  │
│ ├─────────┼──────────┼──────────────────────┤  │
│ │ A       │ @        │ 188.245.245.79       │  │
│ │ A       │ www      │ 188.245.245.79      │  │
│ │ A       │ whatsapp │ 188.245.245.79      │  │ ← Add this
│ └─────────┴──────────┴──────────────────────┘  │
│                                                  │
│ [+ Add Record]                                   │
└─────────────────────────────────────────────────┘
```

## Troubleshooting

### If you can't find DNS Management:

- Look for **DNS** or **Manage DNS** link
- May be under **Advanced DNS** or **DNS Settings**
- Contact GoDaddy support if you can't locate it

### If DNS doesn't resolve after 1 hour:

1. Double-check the A record is saved correctly
2. Verify the IP address is correct: `188.245.245.79`
3. Try clearing your DNS cache:

   ```bash
   # macOS
   sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

   # Linux
   sudo systemd-resolve --flush-caches
   ```

### Test DNS Resolution:

```bash
# Test from command line
nslookup whatsapp.carboncube-ke.com

# Or use dig
dig whatsapp.carboncube-ke.com +short

# Should return: 188.245.245.79
```

## Current Fallback Behavior

**Good news!** Your code already has smart fallback:

- ✅ Will try `whatsapp.carboncube-ke.com` first
- ✅ Automatically falls back to IP (`188.245.245.79`) if domain doesn't resolve
- ✅ Zero downtime during DNS propagation
- ✅ Works seamlessly in both development and production

So you can update `.env` to use the domain **right now**, and it will automatically use the IP until DNS propagates!

## Need Help?

- **GoDaddy Support**: [https://www.godaddy.com/help](https://www.godaddy.com/help)
- **Live Chat**: Available in your GoDaddy account dashboard
- **Phone Support**: Check your GoDaddy account for support numbers
