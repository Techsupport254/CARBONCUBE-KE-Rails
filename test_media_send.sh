#!/bin/bash

PHONE_NUMBER_ID=$(grep '^WHATSAPP_CLOUD_PHONE_NUMBER_ID=' .env | cut -d'=' -f2)
ACCESS_TOKEN=$(grep '^WHATSAPP_CLOUD_ACCESS_TOKEN=' .env | cut -d'=' -f2)

echo "Phone Number ID: $PHONE_NUMBER_ID"

# 1. Download valid small H264 MP4 sample video
curl -s -L -o /tmp/sample_test.mp4 "https://raw.githubusercontent.com/intel-iot-devkit/sample-videos/master/person-bicycle-car-detection.mp4"

ls -lh /tmp/sample_test.mp4

echo "Uploading to Meta Media API..."
MEDIA_RESPONSE=$(curl -s -X POST "https://graph.facebook.com/v20.0/${PHONE_NUMBER_ID}/media" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -F "file=@/tmp/sample_test.mp4;type=video/mp4" \
  -F "type=video/mp4" \
  -F "messaging_product=whatsapp")

echo "Media Upload Response: $MEDIA_RESPONSE"

MEDIA_ID=$(echo "$MEDIA_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

echo "Extracted Media ID: $MEDIA_ID"

if [ -n "$MEDIA_ID" ]; then
  echo "Sending WhatsApp template with Media ID..."
  
  RESPONSE=$(curl -s -X POST "https://graph.facebook.com/v20.0/${PHONE_NUMBER_ID}/messages" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "messaging_product": "whatsapp",
      "recipient_type": "individual",
      "to": "254713063751",
      "type": "template",
      "template": {
        "name": "marketing_campaign",
        "language": { "code": "en" },
        "components": [
          {
            "type": "header",
            "parameters": [
              {
                "type": "video",
                "video": { "id": "'"$MEDIA_ID"'" }
              }
            ]
          },
          {
            "type": "body",
            "parameters": [
              { "type": "text", "parameter_name": "seller_name", "text": "DropSasa" },
              { "type": "text", "parameter_name": "enterprise_name", "text": "DropSasa" }
            ]
          }
        ]
      }
    }')

  echo "Send Template Response: $RESPONSE"
fi
