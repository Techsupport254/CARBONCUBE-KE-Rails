# WhatsApp Number Checker Service

## Simple Setup (2 minutes)

The most reliable way to check if phone numbers are registered on WhatsApp is using this local service.

### Quick Start

1. **Run the setup script:**

   ```bash
   cd backend/whatsapp-service
   ./setup.sh
   ```

2. **Scan the QR code** that appears with your WhatsApp:

   - Open WhatsApp on your phone
   - Go to Settings > Linked Devices
   - Tap "Link a Device"
   - Scan the QR code

3. **That's it!** The service is now running and will accurately check if numbers are on WhatsApp.

### Manual Setup (if needed)

```bash
cd backend/whatsapp-service
npm install
npm start
```

## How It Works

- **Primary Method**: Uses `whatsapp-web.js` library which connects to WhatsApp Web
- **Free**: No API keys or paid services required
- **Accurate**: Uses WhatsApp's official `isRegisteredUser()` method
- **Automatic**: Once set up, works automatically in the background

## Without This Service

If the WhatsApp service is not running, the system will:

- ✅ Still validate phone number format (10 digits, starts with 0 or 7)
- ⚠️ Show WhatsApp button for all valid formats (optimistic approach)
- ✅ Let WhatsApp handle actual verification when users click

## Configuration

Set in your `.env` file:

```bash
WHATSAPP_NOTIFICATIONS_ENABLED=true
WHATSAPP_SERVICE_URL=http://localhost:3002
WHATSAPP_SERVICE_PORT=3002
```

## Production Deployment (VPS)

For production deployment on your VPS, see [PRODUCTION_SETUP.md](./PRODUCTION_SETUP.md)

**Quick deployment:**

```bash
cd /root/CARBON/backend/whatsapp-service
chmod +x deploy-production.sh
sudo ./deploy-production.sh
```

This will set up the service with PM2 (or systemd) for automatic startup and restart on failure.

## API Endpoints

- `GET /health` - Check service health and session status
- `GET /qr` - Get QR code for initial setup
- `POST /send` - Send WhatsApp message
- `POST /restart` - Restart WhatsApp client (for session recovery)
- `POST /logout` - Logout and reset session

## Troubleshooting

### Session Issues

If you see "Session closed" or "Protocol error" messages:

1. **Check service health:**

   ```bash
   node test-health.js
   ```

2. **Restart the client:**

   ```bash
   curl -X POST http://localhost:3002/restart
   ```

3. **If restart doesn't work, logout and rescan:**
   ```bash
   curl -X POST http://localhost:3002/logout
   # Then restart the service and scan QR code again
   ```

### Common Issues

- **Service won't start**: Make sure Node.js is installed (`node --version`)
- **QR code not showing**: Check the terminal output for errors
- **"Session closed" error**: Session expired, restart client or rescan QR
- **"Protocol error"**: Browser session lost, try restart endpoint
- **Connection lost**: Restart the service and scan QR code again
- **Production issues**: See [PRODUCTION_SETUP.md](./PRODUCTION_SETUP.md) for detailed troubleshooting

### Automatic Recovery

The service now includes automatic recovery features:

- Auto-reconnection on disconnection (5-second delay)
- Session validation before sending messages
- Health checks that detect session issues
- Proper error handling with user-friendly messages
