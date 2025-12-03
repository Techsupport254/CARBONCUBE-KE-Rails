#!/usr/bin/env node

// Test script for WhatsApp service health
const http = require("http");

const SERVICE_HOST = "localhost";
const SERVICE_PORT = process.env.WHATSAPP_SERVICE_PORT || 3002;

function checkHealth() {
	return new Promise((resolve, reject) => {
		const options = {
			hostname: SERVICE_HOST,
			port: SERVICE_PORT,
			path: "/health",
			method: "GET",
			timeout: 5000,
		};

		const req = http.request(options, (res) => {
			let data = "";

			res.on("data", (chunk) => {
				data += chunk;
			});

			res.on("end", () => {
				try {
					const health = JSON.parse(data);
					resolve(health);
				} catch (error) {
					reject(new Error("Invalid JSON response"));
				}
			});
		});

		req.on("error", (error) => {
			reject(error);
		});

		req.on("timeout", () => {
			req.destroy();
			reject(new Error("Request timeout"));
		});

		req.end();
	});
}

async function main() {
	console.log("🔍 Testing WhatsApp service health...\n");

	try {
		const health = await checkHealth();

		console.log("📊 Health Check Results:");
		console.log("========================");
		console.log(`Status: ${health.status}`);
		console.log(`WhatsApp Ready: ${health.whatsapp_ready}`);
		console.log(`Session Valid: ${health.session_valid}`);

		if (health.session_error) {
			console.log(`Session Error: ${health.session_error}`);
		}

		console.log(`Timestamp: ${health.timestamp}`);

		if (health.status === "ok" && health.session_valid) {
			console.log("\n✅ Service is healthy and ready to send messages!");
		} else {
			console.log("\n⚠️  Service needs attention:");
			if (!health.whatsapp_ready) {
				console.log("   - WhatsApp client is not ready (scan QR code)");
			}
			if (!health.session_valid) {
				console.log("   - Session is not valid (may need to restart)");
			}
			if (health.session_error) {
				console.log(`   - Session error: ${health.session_error}`);
			}
		}
	} catch (error) {
		console.log("\n❌ Health check failed:");
		console.log(`   ${error.message}`);
		console.log("\n💡 Make sure the WhatsApp service is running:");
		console.log("   ./start-service.sh");
	}
}

main();
