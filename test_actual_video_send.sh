#!/bin/bash

PHONE_NUMBER_ID=$(grep '^WHATSAPP_CLOUD_PHONE_NUMBER_ID=' .env | cut -d'=' -f2)
ACCESS_TOKEN=$(grep '^WHATSAPP_CLOUD_ACCESS_TOKEN=' .env | cut -d'=' -f2)
WABA_ID=$(grep '^WHATSAPP_CLOUD_WABA_ID=' .env | cut -d'=' -f2)

echo "Phone Number ID: $PHONE_NUMBER_ID"
echo "WABA ID: $WABA_ID"

# 1. Fetch exact header_handle from Meta template definition
HEADER_HANDLE=$(curl -s -X GET "https://graph.facebook.com/v20.0/${WABA_ID}/message_templates?name=marketing_campaign" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | grep -o '"header_handle":\["[^"]*"' | cut -d'"' -f4)

echo "Extracted Meta Header Handle: $HEADER_HANDLE"

# 2. Download the ACTUAL video file uploaded to Meta during creation
echo "Downloading actual template video..."
curl -s -L -o /tmp/actual_meta_video.mp4 "$HEADER_HANDLE"

ls -lh /tmp/actual_meta_video.mp4

# 3. Upload the ACTUAL video to Meta Media API
echo "Uploading actual video to Meta Media API..."
MEDIA_RESPONSE=$(curl -s -X POST "https://graph.facebook.com/v20.0/${PHONE_NUMBER_ID}/media" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -F "file=@/tmp/actual_meta_video.mp4;type=video/mp4" \
  -F "type=video/mp4" \
  -F "messaging_product=whatsapp")

echo "Media Upload Response: $MEDIA_RESPONSE"

MEDIA_ID=$(echo "$MEDIA_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

echo "Extracted Media ID: $MEDIA_ID"

if [ -n "$MEDIA_ID" ]; then
  for RECIPIENT in "254713063751" "254716404137"; do
    echo "Sending marketing_campaign with actual video Media ID to $RECIPIENT..."
    
    RESPONSE=$(curl -s -X POST "https://graph.facebook.com/v20.0/${PHONE_NUMBER_ID}/messages" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": "'"$RECIPIENT"'",
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

    echo "Send Response for $RECIPIENT: $RESPONSE"
  done
fi
