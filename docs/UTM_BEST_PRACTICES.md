# UTM Parameter Best Practices for Share/Copy Actions

## Overview

UTM parameters should follow Google Analytics best practices. For share and copy actions, we need to distinguish between:

- **Where** the link is shared (source)
- **How** it's shared (medium)
- **What** is being shared (campaign/content)

## Current Issue

Using `utm_source="copy"` is incorrect because:

- `copy` is an **action**, not a **source**
- It gets categorized as "other" in analytics
- It doesn't provide meaningful tracking data

## Best Practice Structure

### For Share Actions (Facebook, Twitter, WhatsApp, LinkedIn)

```javascript
{
  utm_source: "facebook" | "twitter" | "whatsapp" | "linkedin",  // Actual platform
  utm_medium: "share",                                             // How it's shared
  utm_campaign: "shop_share" | "ad_share" | "product_share",      // What's shared
  utm_content: "shop_123" | "ad_456" | "product_789",              // Specific ID
  utm_term: "Shop Name" | "Product Title"                         // Optional: Name/title
}
```

### For Copy Link Action

**Option 1: Omit source (Recommended)**

```javascript
{
  utm_source: undefined,  // Don't set - we don't know where it will be shared
  utm_medium: "share",    // How it's shared
  utm_campaign: "shop_share" | "ad_share" | "product_share",
  utm_content: "shop_123" | "ad_456",
  utm_term: "Shop Name"
}
```

**Option 2: Use referrer tracking**

```javascript
{
  utm_source: undefined,  // Will be determined by referrer when link is clicked
  utm_medium: "referral", // Indicates it's a referral/share
  utm_campaign: "shop_share" | "ad_share" | "product_share",
  utm_content: "shop_123" | "ad_456"
}
```

## Recommended Implementation

### For Share Actions:

- **utm_source**: Platform name (facebook, twitter, whatsapp, linkedin)
- **utm_medium**: "share" (more specific than "social")
- **utm_campaign**: "shop_share", "ad_share", or "product_share"
- **utm_content**: Shop ID, Ad ID, or Product ID
- **utm_term**: Shop name, Product title (optional)

### For Copy Link:

- **utm_source**: Omit/undefined (will be tracked via referrer when clicked)
- **utm_medium**: "share" or "referral"
- **utm_campaign**: "shop_share", "ad_share", or "product_share"
- **utm_content**: Shop ID, Ad ID, or Product ID
- **utm_term**: Shop name, Product title (optional)

## Benefits

1. **Accurate Source Tracking**: Real platforms are tracked correctly
2. **No Invalid Sources**: "copy" won't appear as a source
3. **Better Analytics**: Can distinguish between share types and platforms
4. **Referrer Fallback**: For copied links, referrer header will show actual source when clicked

## Example URLs

**Shop Share to Facebook:**

```
https://carboncube-ke.com/shop/example-shop?utm_source=facebook&utm_medium=share&utm_campaign=shop_share&utm_content=shop_123&utm_term=Example%20Shop
```

**Copy Shop Link:**

```
https://carboncube-ke.com/shop/example-shop?utm_medium=share&utm_campaign=shop_share&utm_content=shop_123&utm_term=Example%20Shop
```

**Ad Share to WhatsApp:**

```
https://carboncube-ke.com/ad/example-ad?utm_source=whatsapp&utm_medium=share&utm_campaign=ad_share&utm_content=ad_456
```
