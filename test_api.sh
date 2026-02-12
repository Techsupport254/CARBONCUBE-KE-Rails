#!/bin/bash

# Test script for CarbonMobile API endpoints
# User: optisoftkenya@gmail.com (DropSasa - Seller)

echo "🔐 Testing CarbonMobile API Endpoints"
echo "======================================"
echo ""

# Login and get token
echo "1️⃣  Testing Login..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "optisoftkenya@gmail.com",
    "password": "33QuainT23@Kirui"
  }')

TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')
USER_NAME=$(echo $LOGIN_RESPONSE | jq -r '.user.name')
USER_ROLE=$(echo $LOGIN_RESPONSE | jq -r '.user.role')

if [ "$TOKEN" != "null" ]; then
  echo "✅ Login successful!"
  echo "   User: $USER_NAME ($USER_ROLE)"
  echo "   Token: ${TOKEN:0:50}..."
else
  echo "❌ Login failed!"
  exit 1
fi

echo ""
echo "2️⃣  Testing Notifications Endpoint..."
NOTIF_RESPONSE=$(curl -s -X GET http://localhost:3001/notifications \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN")

TOTAL_NOTIF=$(echo $NOTIF_RESPONSE | jq -r '.meta.total_count')
UNREAD_NOTIF=$(echo $NOTIF_RESPONSE | jq -r '.meta.unread_count')

if [ "$TOTAL_NOTIF" != "null" ]; then
  echo "✅ Notifications endpoint working!"
  echo "   Total: $TOTAL_NOTIF | Unread: $UNREAD_NOTIF"
else
  echo "❌ Notifications endpoint failed!"
  echo "   Response: $NOTIF_RESPONSE"
fi

echo ""
echo "3️⃣  Testing Messages Unread Count..."
MSG_RESPONSE=$(curl -s -X GET http://localhost:3001/conversations/unread_count \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN")

UNREAD_MSG=$(echo $MSG_RESPONSE | jq -r '.count')

if [ "$UNREAD_MSG" != "null" ]; then
  echo "✅ Messages unread count working!"
  echo "   Unread messages: $UNREAD_MSG"
else
  echo "❌ Messages endpoint failed!"
  echo "   Response: $MSG_RESPONSE"
fi

echo ""
echo "4️⃣  Testing Conversations List..."
CONV_RESPONSE=$(curl -s -X GET http://localhost:3001/conversations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN")

CONV_COUNT=$(echo $CONV_RESPONSE | jq -r '.conversations | length')

if [ "$CONV_COUNT" != "null" ]; then
  echo "✅ Conversations endpoint working!"
  echo "   Total conversations: $CONV_COUNT"
else
  echo "❌ Conversations endpoint failed!"
fi

echo ""
echo "======================================"
echo "📊 Summary:"
echo "   Notifications: $UNREAD_NOTIF unread / $TOTAL_NOTIF total"
echo "   Messages: $UNREAD_MSG unread conversations"
echo "   Conversations: $CONV_COUNT total"
echo "======================================"
