#!/bin/bash

# Test script for WhatsApp product creation via webhook
# This script simulates WhatsApp webhook events to test the product creation flow

BASE_URL="http://localhost:3001"
WEBHOOK_URL="${BASE_URL}/webhooks/whatsapp"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "WhatsApp Product Creation Test Script"
echo "=========================================="
echo ""

# Test 1: Verify webhook endpoint is accessible
echo -e "${YELLOW}Test 1: Checking webhook endpoint...${NC}"
response=$(curl -s -o /dev/null -w "%{http_code}" "${WEBHOOK_URL}")
if [ "$response" -eq 200 ] || [ "$response" -eq 404 ] || [ "$response" -eq 405 ]; then
    echo -e "${GREEN}✓ Webhook endpoint is accessible (HTTP $response)${NC}"
else
    echo -e "${RED}✗ Webhook endpoint returned HTTP $response${NC}"
fi
echo ""

# Test 2: Simulate webhook verification (GET request)
echo -e "${YELLOW}Test 2: Testing webhook verification...${NC}"
VERIFY_TOKEN="test_verify_token_12345"
response=$(curl -s -X GET \
  "${WEBHOOK_URL}?hub.mode=subscribe&hub.challenge=test_challenge&hub.verify_token=${VERIFY_TOKEN}" \
  -w "\nHTTP_CODE:%{http_code}")
echo "Response: $response"
echo ""

# Test 3: Create a test seller for testing
echo -e "${YELLOW}Test 3: Creating test seller...${NC}"
SELLER_RESPONSE=$(curl -s -X POST "${BASE_URL}/seller/signup" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test_whatsapp_seller@example.com",
    "phone_number": "0712345678",
    "fullname": "Test WhatsApp Seller",
    "enterprise_name": "Test Enterprise",
    "location": "Nairobi",
    "password": "TestPassword123!",
    "county_id": 1,
    "sub_county_id": 1
  }')
echo "Seller creation response: $SELLER_RESPONSE"
echo ""

# Extract seller ID if successful
SELLER_ID=$(echo $SELLER_RESPONSE | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
if [ -n "$SELLER_ID" ]; then
    echo -e "${GREEN}✓ Test seller created with ID: $SELLER_ID${NC}"
else
    echo -e "${RED}✗ Failed to create test seller${NC}"
    echo "Trying to use existing seller..."
    SELLER_ID="existing"
fi
echo ""

# Test 4: Simulate WhatsApp message with ADD command
echo -e "${YELLOW}Test 4: Simulating ADD command from seller...${NC}"
WEBHOOK_PAYLOAD='{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "123456789",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "254712345678",
              "phone_number_id": "123456789"
            },
            "messages": [
              {
                "from": "254712345678",
                "id": "wamid.example",
                "timestamp": "1695123456",
                "type": "text",
                "text": {
                  "body": "ADD"
                }
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}'

echo "Sending webhook payload..."
WEBHOOK_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$WEBHOOK_PAYLOAD" \
  -w "\nHTTP_CODE:%{http_code}")
echo "Webhook response: $WEBHOOK_RESPONSE"
echo ""

# Test 5: Check if session was created
echo -e "${YELLOW}Test 5: Checking WhatsApp product session...${NC}"
SESSION_CHECK=$(curl -s "${BASE_URL}/whatsapp_product_sessions" 2>/dev/null || echo "Endpoint not available")
echo "Session check: $SESSION_CHECK"
echo ""

# Test 6: Simulate product title
echo -e "${YELLOW}Test 6: Simulating product title...${NC}"
TITLE_PAYLOAD='{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "123456789",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "254712345678",
              "phone_number_id": "123456789"
            },
            "messages": [
              {
                "from": "254712345678",
                "id": "wamid.example2",
                "timestamp": "1695123457",
                "type": "text",
                "text": {
                  "body": "Samsung Galaxy S21 Ultra 5G"
                }
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}'

echo "Sending title payload..."
TITLE_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$TITLE_PAYLOAD" \
  -w "\nHTTP_CODE:%{http_code}")
echo "Title response: $TITLE_RESPONSE"
echo ""

# Test 7: Simulate product description
echo -e "${YELLOW}Test 7: Simulating product description...${NC}"
DESCRIPTION_PAYLOAD='{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "123456789",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "254712345678",
              "phone_number_id": "123456789"
            },
            "messages": [
              {
                "from": "254712345678",
                "id": "wamid.example3",
                "timestamp": "1695123458",
                "type": "text",
                "text": {
                  "body": "Brand new Samsung Galaxy S21 Ultra 5G with 128GB storage. Comes with original box and accessories. 1 year warranty included."
                }
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}'

echo "Sending description payload..."
DESCRIPTION_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$DESCRIPTION_PAYLOAD" \
  -w "\nHTTP_CODE:%{http_code}")
echo "Description response: $DESCRIPTION_RESPONSE"
echo ""

# Test 8: Simulate price
echo -e "${YELLOW}Test 8: Simulating price...${NC}"
PRICE_PAYLOAD='{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "123456789",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "254712345678",
              "phone_number_id": "123456789"
            },
            "messages": [
              {
                "from": "254712345678",
                "id": "wamid.example4",
                "timestamp": "1695123459",
                "type": "text",
                "text": {
                  "body": "85000"
                }
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}'

echo "Sending price payload..."
PRICE_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$PRICE_PAYLOAD" \
  -w "\nHTTP_CODE:%{http_code}")
echo "Price response: $PRICE_RESPONSE"
echo ""

# Test 9: Simulate category selection
echo -e "${YELLOW}Test 9: Simulating category selection...${NC}"
CATEGORY_PAYLOAD='{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "123456789",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "254712345678",
              "phone_number_id": "123456789"
            },
            "messages": [
              {
                "from": "254712345678",
                "id": "wamid.example5",
                "timestamp": "1695123460",
                "type": "text",
                "text": {
                  "body": "phones"
                }
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}'

echo "Sending category payload..."
CATEGORY_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$CATEGORY_PAYLOAD" \
  -w "\nHTTP_CODE:%{http_code}")
echo "Category response: $CATEGORY_RESPONSE"
echo ""

# Test 10: Simulate brand
echo -e "${YELLOW}Test 10: Simulating brand...${NC}"
BRAND_PAYLOAD='{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "123456789",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "254712345678",
              "phone_number_id": "123456789"
            },
            "messages": [
              {
                "from": "254712345678",
                "id": "wamid.example6",
                "timestamp": "1695123461",
                "type": "text",
                "text": {
                  "body": "Samsung"
                }
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}'

echo "Sending brand payload..."
BRAND_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$BRAND_PAYLOAD" \
  -w "\nHTTP_CODE:%{http_code}")
echo "Brand response: $BRAND_RESPONSE"
echo ""

# Test 11: Simulate condition
echo -e "${YELLOW}Test 11: Simulating condition...${NC}"
CONDITION_PAYLOAD='{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "123456789",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "254712345678",
              "phone_number_id": "123456789"
            },
            "messages": [
              {
                "from": "254712345678",
                "id": "wamid.example7",
                "timestamp": "1695123462",
                "type": "text",
                "text": {
                  "body": "1"
                }
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}'

echo "Sending condition payload..."
CONDITION_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$CONDITION_PAYLOAD" \
  -w "\nHTTP_CODE:%{http_code}")
echo "Condition response: $CONDITION_RESPONSE"
echo ""

# Test 12: Simulate skipping images
echo -e "${YELLOW}Test 12: Simulating image skip...${NC}"
SKIP_IMAGES_PAYLOAD='{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "123456789",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "254712345678",
              "phone_number_id": "123456789"
            },
            "messages": [
              {
                "from": "254712345678",
                "id": "wamid.example8",
                "timestamp": "1695123463",
                "type": "text",
                "text": {
                  "body": "SKIP"
                }
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}'

echo "Sending skip images payload..."
SKIP_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$SKIP_IMAGES_PAYLOAD" \
  -w "\nHTTP_CODE:%{http_code}")
echo "Skip images response: $SKIP_RESPONSE"
echo ""

# Test 13: Simulate confirmation
echo -e "${YELLOW}Test 13: Simulating product confirmation...${NC}"
CONFIRM_PAYLOAD='{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "123456789",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "254712345678",
              "phone_number_id": "123456789"
            },
            "messages": [
              {
                "from": "254712345678",
                "id": "wamid.example9",
                "timestamp": "1695123464",
                "type": "text",
                "text": {
                  "body": "CONFIRM"
                }
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}'

echo "Sending confirm payload..."
CONFIRM_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$CONFIRM_PAYLOAD" \
  -w "\nHTTP_CODE:%{http_code}")
echo "Confirm response: $CONFIRM_RESPONSE"
echo ""

# Test 14: Test HELP command
echo -e "${YELLOW}Test 14: Testing HELP command...${NC}"
HELP_PAYLOAD='{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "123456789",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "254712345678",
              "phone_number_id": "123456789"
            },
            "messages": [
              {
                "from": "254712345678",
                "id": "wamid.example10",
                "timestamp": "1695123465",
                "type": "text",
                "text": {
                  "body": "HELP"
                }
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}'

echo "Sending help payload..."
HELP_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$HELP_PAYLOAD" \
  -w "\nHTTP_CODE:%{http_code}")
echo "Help response: $HELP_RESPONSE"
echo ""

# Test 15: Test CANCEL command
echo -e "${YELLOW}Test 15: Testing CANCEL command...${NC}"
CANCEL_PAYLOAD='{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "123456789",
      "changes": [
        {
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "254712345678",
              "phone_number_id": "123456789"
            },
            "messages": [
              {
                "from": "254712345678",
                "id": "wamid.example11",
                "timestamp": "1695123466",
                "type": "text",
                "text": {
                  "body": "CANCEL"
                }
              }
            ]
          },
          "field": "messages"
        }
      ]
    }
  ]
}'

echo "Sending cancel payload..."
CANCEL_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$CANCEL_PAYLOAD" \
  -w "\nHTTP_CODE:%{http_code}")
echo "Cancel response: $CANCEL_RESPONSE"
echo ""

echo "=========================================="
echo "Test Script Completed"
echo "=========================================="
echo ""
echo "Note: For the webhook to work properly, ensure:"
echo "1. Rails server is running on port 3000"
echo "2. WHATSAPP_CLOUD_ACCESS_TOKEN and WHATSAPP_CLOUD_PHONE_NUMBER_ID are set in .env"
echo "3. The seller phone number (0712345678) exists in the database"
echo "4. The seller has an active subscription tier"
