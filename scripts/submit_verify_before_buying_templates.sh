#!/bin/bash
# Submit "Verify Before You Buy" WhatsApp templates to Meta for approval.
# Run this script to create both buyer and seller versions.
#
# Usage: bash submit_verify_before_buying_templates.sh

ACCESS_TOKEN="EAAYYNyfGF3sBQ08dnI4Prk0a22wTftj98J6wOz6ZAhFzPTZAseBOGZAuxnUj67OwZBKvrdIMVDw9SVFhY70MWCfbcgBP4HelPDH8iBlKCfk6DjuvtV2wMpI9tEgGbwQazu5PJ0Py8m4pBH1OTgMIXNTq9MSx7NoZB5FWyWERoSXuTfB7aGADdoNyNHGA2zX8mswZDZD"
WA_NUMBER_ID="1226679169649495"
API_URL="https://graph.facebook.com/v22.0/${WA_NUMBER_ID}/message_templates"

echo "=== Submitting BUYER template: verify_before_buying_buyers_v1 ==="
curl -s -k -X POST "${API_URL}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "verify_before_buying_buyers_v1",
    "language": "en_US",
    "category": "MARKETING",
    "components": [
      {
        "type": "BODY",
        "text": "*Verify Before You Buy*\n\nHello,\n\nBefore purchasing a product, ask the seller any questions you may have. _Confirm the product details, price, and condition_ to help you make an informed decision.\n\n⚠️ *Important:* Avoid making full payment before receiving or inspecting the product unless you trust the seller.\n\n*Shop smart and make informed decisions.*\n\nRegards,\n*Carbon Cube Kenya*"
      },
      {
        "type": "BUTTONS",
        "buttons": [
          {
            "type": "URL",
            "text": "Browse Products",
            "url": "https://carboncube-ke.com/?utm_source=whatsapp&utm_medium=broadcast&utm_campaign=verify_before_buying&utm_content=home"
          }
        ]
      }
    ]
  }' | python3 -m json.tool

echo ""
echo "=== Submitting SELLER template: verify_before_buying_sellers_v1 ==="
curl -s -k -X POST "${API_URL}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "verify_before_buying_sellers_v1",
    "language": "en_US",
    "category": "MARKETING",
    "components": [
      {
        "type": "BODY",
        "text": "*Verify Before You Buy*\n\nHello,\n\nBefore purchasing a product, ask the seller any questions you may have. _Confirm the product details, price, and condition_ to help you make an informed decision.\n\n⚠️ *Important:* Avoid making full payment before receiving or inspecting the product unless you trust the seller.\n\n*Shop smart and make informed decisions.*\n\nRegards,\n*Carbon Cube Kenya*"
      },
      {
        "type": "BUTTONS",
        "buttons": [
          {
            "type": "URL",
            "text": "Your Dashboard",
            "url": "https://carboncube-ke.com/seller/dashboard?utm_source=whatsapp&utm_medium=broadcast&utm_campaign=verify_before_buying&utm_content=seller_dashboard"
          },
          {
            "type": "URL",
            "text": "Manage Your Ads",
            "url": "https://carboncube-ke.com/seller/ads?utm_source=whatsapp&utm_medium=broadcast&utm_campaign=verify_before_buying&utm_content=seller_ads"
          }
        ]
      }
    ]
  }' | python3 -m json.tool

echo ""
echo "=== Done. Check status with: ==="
echo "curl -s -k \"${API_URL}?limit=100\" -H \"Authorization: Bearer ${ACCESS_TOKEN}\" | python3 -c \"import sys,json; [print(f\\\"{t['name']}: {t['status']}\\\") for t in json.load(sys.stdin).get('data',[]) if 'verify_before' in t.get('name','')]\""
