const { Client, LocalAuth } = require("whatsapp-web.js");
const express = require("express");
const qrcode = require("qrcode-terminal");
require("dotenv").config();

const app = express();
app.use(express.json());

// Use port 3002 by default to avoid conflict with Rails (which uses 3001)
const PORT = process.env.WHATSAPP_SERVICE_PORT || 3002;

let client = null;
let isReady = false;
let qrCode = null;

// Function to create and initialize WhatsApp client
function createClient() {
	client = new Client({
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
}

// Initialize client on startup
createClient();

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

// Logout and reset session endpoint (to rescan with different WhatsApp account)
app.post("/logout", async (req, res) => {
	try {
		if (client) {
			if (isReady) {
				try {
					await client.logout();
					console.log("WhatsApp client logged out");
				} catch (e) {
					console.log("Logout error (may already be logged out):", e.message);
				}
			}

			// Destroy the client to clear the session
			try {
				await client.destroy();
				console.log("WhatsApp client destroyed");
			} catch (e) {
				console.log("Destroy error:", e.message);
			}
		}

		// Clear the authentication data directory
		const fs = require("fs");
		const path = require("path");
		const authPath = path.join(__dirname, ".wwebjs_auth");

		if (fs.existsSync(authPath)) {
			fs.rmSync(authPath, { recursive: true, force: true });
			console.log("Authentication data cleared");
		}

		// Reset state and recreate the client to generate a new QR code
		isReady = false;
		qrCode = null;
		client = null;

		// Wait a moment before recreating to ensure cleanup is complete
		setTimeout(() => {
			createClient();
		}, 1000);

		res.json({
			success: true,
			message:
				"Logged out successfully. A new QR code will be generated shortly. Please scan it with your phone.",
			qrEndpoint: `http://localhost:${PORT}/qr`,
		});
	} catch (error) {
		console.error("Error during logout:", error);
		res.status(500).json({
			error: "Failed to logout",
			message: error.message,
		});
	}
});

// Send message endpoint
app.post("/send", async (req, res) => {
	if (!client || !isReady) {
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
	if (client) {
		try {
			await client.destroy();
		} catch (e) {
			console.log("Error during shutdown:", e.message);
		}
	}
	process.exit(0);
});
