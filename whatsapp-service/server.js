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

	// Loading screen
	client.on("loading_screen", (percent, message) => {
		console.log(`Loading: ${percent}% - ${message}`);
	});

	// Authenticated
	client.on("authenticated", () => {
		console.log("WhatsApp client authenticated");
	});

	// Authentication failure
	client.on("auth_failure", (msg) => {
		if (process.env.NODE_ENV === "development") {
			console.error("Authentication failure:", msg);
		}
		isReady = false;
	});

	// Disconnected
	client.on("disconnected", (reason) => {
		if (process.env.NODE_ENV === "development") {
			console.log("Client disconnected:", reason);
		}
		isReady = false;
		// Attempt to reconnect after a delay
		setTimeout(() => {
			console.log("Attempting to reconnect WhatsApp client...");
			createClient();
		}, 5000); // Wait 5 seconds before reconnecting
	});

	// Message event (can help detect session issues)
	client.on("message", (msg) => {
		if (process.env.NODE_ENV === "development") {
			console.log(
				"Received message:",
				msg.from,
				msg.body?.substring(0, 50) + "...",
			);
		}
	});

	// Message create event
	client.on("message_create", (msg) => {
		if (process.env.NODE_ENV === "development" && msg.fromMe) {
			console.log("Sent message:", msg.to, msg.body?.substring(0, 50) + "...");
		}
	});

	// Handle session state changes
	client.on("change_state", (state) => {
		console.log("Client state changed:", state);
		if (state !== "CONNECTED") {
			isReady = false;
		} else {
			isReady = true;
		}
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
app.get("/health", async (req, res) => {
	let sessionValid = false;
	let sessionError = null;

	if (client && isReady) {
		try {
			// Try to get client state to validate session is active
			const state = await client.getState();
			sessionValid = state === "CONNECTED";
		} catch (error) {
			console.error("Health check session validation failed:", error.message);
			sessionError = error.message;
			if (
				error.message.includes("Session closed") ||
				error.message.includes("Protocol error")
			) {
				isReady = false;
			}
		}
	}

	res.json({
		status: sessionValid ? "ok" : "session_issue",
		whatsapp_ready: isReady,
		session_valid: sessionValid,
		session_error: sessionError,
		timestamp: new Date().toISOString(),
	});
});

// Status summary (check if already connected)
app.get("/status", async (req, res) => {
	let sessionValid = false;
	if (client && isReady) {
		try {
			const state = await client.getState();
			sessionValid = state === "CONNECTED";
		} catch (_) {}
	}
	const connected = sessionValid;
	res.json({
		connected,
		message: connected
			? "WhatsApp is already connected — no scan needed."
			: qrCode
				? "Scan the QR at /scan or wait for QR in terminal."
				: "Starting up or QR not ready yet. Try GET /scan in a few seconds.",
		isReady,
		hasQr: !!qrCode,
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

// Scan page: HTML that shows a scannable QR (open in browser)
app.get("/scan", (req, res) => {
	const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Scan WhatsApp QR</title>
  <style>
    body { font-family: system-ui; text-align: center; padding: 2rem; }
    #msg { margin: 1rem 0; color: #666; }
    #qrcode { margin: 1rem auto; }
    img { max-width: 300px; height: auto; }
  </style>
</head>
<body>
  <h1>Link WhatsApp</h1>
  <p id="msg">Loading…</p>
  <div id="qrcode"></div>
  <script>
    function check() {
      fetch('/qr')
        .then(r => r.json())
        .then(d => {
          if (d.qr) {
            document.getElementById('msg').textContent = 'Scan this QR with WhatsApp: Settings → Linked devices → Link a device';
            var el = document.getElementById('qrcode');
            el.innerHTML = '';
            var img = document.createElement('img');
            img.src = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=' + encodeURIComponent(d.qr);
            img.alt = 'QR Code';
            el.appendChild(img);
          } else if (d.message && d.message.includes('already connected')) {
            document.getElementById('msg').textContent = 'Already connected. No scan needed.';
            document.getElementById('qrcode').innerHTML = '';
          } else {
            document.getElementById('msg').textContent = 'QR not ready. Retrying in 2s…';
            document.getElementById('qrcode').innerHTML = '';
            setTimeout(check, 2000);
          }
        })
        .catch(() => {
          document.getElementById('msg').textContent = 'Cannot reach service. Retrying in 2s…';
          setTimeout(check, 2000);
        });
    }
    check();
  </script>
</body>
</html>`;
	res.setHeader("Content-Type", "text/html");
	res.send(html);
});

// Restart client endpoint (for session recovery)
app.post("/restart", async (req, res) => {
	try {
		if (client) {
			try {
				await client.destroy();
				console.log("Client destroyed for restart");
			} catch (error) {
				console.log(
					"Error destroying client (may already be destroyed):",
					error.message,
				);
			}
		}

		isReady = false;
		qrCode = null;

		console.log("Creating new WhatsApp client...");
		createClient();

		res.json({
			message: "WhatsApp client restart initiated",
			timestamp: new Date().toISOString(),
		});
	} catch (error) {
		console.error("Error restarting client:", error.message);
		res.status(500).json({
			error: "Failed to restart WhatsApp client",
			details: error.message,
		});
	}
});

// Logout and reset session endpoint (to rescan with different WhatsApp account)
app.post("/logout", async (req, res) => {
	try {
		if (client) {
			if (isReady) {
				try {
					await client.logout();
					if (process.env.NODE_ENV === "development") {
						console.log("WhatsApp client logged out");
					}
				} catch (e) {
					if (process.env.NODE_ENV === "development") {
						console.log("Logout error (may already be logged out):", e.message);
					}
				}
			}

			// Destroy the client to clear the session
			try {
				await client.destroy();
				if (process.env.NODE_ENV === "development") {
					console.log("WhatsApp client destroyed");
				}
			} catch (e) {
				if (process.env.NODE_ENV === "development") {
					console.log("Destroy error:", e.message);
				}
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

// Check if phone number is registered on WhatsApp endpoint
app.post("/check", async (req, res) => {
	if (!client || !isReady) {
		return res.status(503).json({
			error: "WhatsApp client is not ready",
			message: "Please scan the QR code first or wait for connection",
			isRegistered: false,
		});
	}

	const { phoneNumber } = req.body;

	if (!phoneNumber) {
		return res.status(400).json({
			error: "Phone number is required",
			isRegistered: false,
		});
	}

	try {
		const formattedNumber = formatPhoneNumber(phoneNumber);

		// Check if number is registered on WhatsApp
		const isRegistered = await client.isRegisteredUser(formattedNumber);

		res.json({
			success: true,
			isRegistered: isRegistered,
			phoneNumber: phoneNumber,
			formattedNumber: formattedNumber,
			timestamp: new Date().toISOString(),
		});
	} catch (error) {
		console.error("Error checking WhatsApp number:", error);
		res.status(500).json({
			error: "Failed to check phone number",
			message: error.message,
			isRegistered: false,
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

	// Additional session validation - try to access client info to ensure session is active
	try {
		await client.getState();
	} catch (error) {
		console.error("Client session validation failed:", error.message);
		isReady = false;
		return res.status(503).json({
			error: "WhatsApp session has expired",
			message: "Please restart the service and scan QR code again",
		});
	}

	const { phoneNumber, message, imagePath } = req.body;

	// Debug logging
	if (process.env.NODE_ENV === "development") {
		console.log("=== WhatsApp Send Request ===");
		console.log("Phone number:", phoneNumber);
		console.log("Message length:", message ? message.length : 0);
		console.log("Image path:", imagePath || "NOT PROVIDED");
		if (imagePath) {
			const fs = require("fs");
			console.log("Image exists:", fs.existsSync(imagePath));
			if (fs.existsSync(imagePath)) {
				const stats = fs.statSync(imagePath);
				console.log("Image size:", stats.size, "bytes");
			}
		}
	}

	if (!phoneNumber || !message) {
		return res.status(400).json({
			error: "Missing required fields",
			required: ["phoneNumber", "message"],
		});
	}

	try {
		const formattedNumber = formatPhoneNumber(phoneNumber);

		// Check if number is registered on WhatsApp (with error handling)
		let isRegistered;
		try {
			isRegistered = await client.isRegisteredUser(formattedNumber);
		} catch (error) {
			console.error("Error checking user registration:", error.message);
			if (
				error.message.includes("Session closed") ||
				error.message.includes("Protocol error")
			) {
				isReady = false;
				return res.status(503).json({
					error: "WhatsApp session expired",
					message: "Please restart the service and scan QR code again",
				});
			}
			throw error;
		}

		if (!isRegistered) {
			return res.status(400).json({
				error: "Phone number is not registered on WhatsApp",
				phoneNumber: phoneNumber,
			});
		}

		let result;

		// Send message with image if imagePath is provided
		if (imagePath) {
			const fs = require("fs");
			const path = require("path");

			// Check if image file exists
			if (!fs.existsSync(imagePath)) {
				if (process.env.NODE_ENV === "development") {
					console.error("Image file not found:", imagePath);
				}
				return res.status(400).json({
					error: "Image file not found",
					imagePath: imagePath,
				});
			}

			if (process.env.NODE_ENV === "development") {
				console.log("Sending image with caption...");
			}

			// Send image with caption
			const MessageMedia = require("whatsapp-web.js").MessageMedia;
			const media = MessageMedia.fromFilePath(imagePath);

			// Ensure MIME type is set correctly for PNG images
			if (!media.mimetype || media.mimetype === "application/octet-stream") {
				media.mimetype = "image/png";
			}

			media.caption = message;

			if (process.env.NODE_ENV === "development") {
				console.log("Media MIME type:", media.mimetype);
				console.log("Media filename:", media.filename);
			}

			try {
				// sendSeen: false avoids "markedUnread" TypeError when WhatsApp Web UI has changed
				result = await client.sendMessage(formattedNumber, media, {
					sendSeen: false,
				});
			} catch (error) {
				console.error("Error sending image message:", error.message);
				if (
					error.message.includes("Session closed") ||
					error.message.includes("Protocol error")
				) {
					isReady = false;
					return res.status(503).json({
						error: "WhatsApp session expired during send",
						message: "Please restart the service and scan QR code again",
					});
				}
				throw error;
			}

			if (process.env.NODE_ENV === "development") {
				console.log("Image message sent successfully");
			}
		} else {
			if (process.env.NODE_ENV === "development") {
				console.log("Sending text message only (no image)...");
			}
			try {
				// sendSeen: false avoids "markedUnread" TypeError when WhatsApp Web UI has changed
				result = await client.sendMessage(formattedNumber, message, {
					sendSeen: false,
				});
			} catch (error) {
				console.error("Error sending text message:", error.message);
				if (
					error.message.includes("Session closed") ||
					error.message.includes("Protocol error")
				) {
					isReady = false;
					return res.status(503).json({
						error: "WhatsApp session expired during send",
						message: "Please restart the service and scan QR code again",
					});
				}
				throw error;
			}
		}

		res.json({
			success: true,
			messageId: result.id._serialized,
			phoneNumber: phoneNumber,
			formattedNumber: formattedNumber,
			hasImage: !!imagePath,
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
