const { Client, LocalAuth } = require("whatsapp-web.js");
const express = require("express");
const qrcode = require("qrcode-terminal");
require("dotenv").config();

const app = express();
app.use(express.json());

const PORT = process.env.WHATSAPP_SERVICE_PORT || 3001;

// Initialize WhatsApp client
const client = new Client({
	authStrategy: new LocalAuth({
		dataPath: "./.wwebjs_auth",
	}),
	puppeteer: {
		headless: true,
		args: [
			"--no-sandbox",
			"--disable-setuid-sandbox",
			"--disable-dev-shm-usage",
			"--disable-accelerated-2d-canvas",
			"--no-first-run",
			"--no-zygote",
			"--single-process",
			"--disable-gpu",
		],
	},
});

let isReady = false;
let qrCode = null;

// QR code generation
client.on("qr", (qr) => {
	console.log("QR Code received, scan with your phone:");
	qrcode.generate(qr, { small: true });
	qrCode = qr;
});

// Client ready
client.on("ready", () => {
	console.log("WhatsApp client is ready!");
	isReady = true;
	qrCode = null;
});

// Authentication failure
client.on("auth_failure", (msg) => {
	console.error("Authentication failure:", msg);
	isReady = false;
});

// Disconnected
client.on("disconnected", (reason) => {
	console.log("Client disconnected:", reason);
	isReady = false;
});

// Initialize client
client.initialize();

// Helper function to format phone number (Kenyan format: 07XXXXXXXX -> 2547XXXXXXXX)
function formatPhoneNumber(phoneNumber) {
	// Remove any non-digit characters
	let cleaned = phoneNumber.replace(/\D/g, "");

	// If it starts with 0, replace with 254
	if (cleaned.startsWith("0")) {
		cleaned = "254" + cleaned.substring(1);
	}

	// If it doesn't start with country code, add 254
	if (!cleaned.startsWith("254")) {
		cleaned = "254" + cleaned;
	}

	// Return with @c.us suffix for WhatsApp
	return cleaned + "@c.us";
}

// Health check endpoint
app.get("/health", (req, res) => {
	res.json({
		status: "ok",
		whatsapp_ready: isReady,
		timestamp: new Date().toISOString(),
	});
});

// Get QR code endpoint (for initial setup)
app.get("/qr", (req, res) => {
	if (qrCode) {
		res.json({ qr: qrCode });
	} else if (isReady) {
		res.json({ message: "WhatsApp is already connected" });
	} else {
		res.status(503).json({ error: "QR code not available yet" });
	}
});

// Send message endpoint
app.post("/send", async (req, res) => {
	if (!isReady) {
		return res.status(503).json({
			error: "WhatsApp client is not ready",
			message: "Please scan the QR code first or wait for connection",
		});
	}

	const { phoneNumber, message } = req.body;

	if (!phoneNumber || !message) {
		return res.status(400).json({
			error: "Missing required fields",
			required: ["phoneNumber", "message"],
		});
	}

	try {
		const formattedNumber = formatPhoneNumber(phoneNumber);

		// Check if number is registered on WhatsApp
		const isRegistered = await client.isRegisteredUser(formattedNumber);

		if (!isRegistered) {
			return res.status(400).json({
				error: "Phone number is not registered on WhatsApp",
				phoneNumber: phoneNumber,
			});
		}

		// Send message
		const result = await client.sendMessage(formattedNumber, message);

		res.json({
			success: true,
			messageId: result.id._serialized,
			phoneNumber: phoneNumber,
			formattedNumber: formattedNumber,
			timestamp: new Date().toISOString(),
		});
	} catch (error) {
		console.error("Error sending WhatsApp message:", error);
		res.status(500).json({
			error: "Failed to send message",
			message: error.message,
		});
	}
});

// Start server
app.listen(PORT, () => {
	console.log(`WhatsApp service running on port ${PORT}`);
	console.log(`Health check: http://localhost:${PORT}/health`);
	console.log(`QR code: http://localhost:${PORT}/qr`);
});

// Graceful shutdown
process.on("SIGINT", async () => {
	console.log("Shutting down...");
	await client.destroy();
	process.exit(0);
});
