// Quick script to display QR code from WhatsApp service
const https = require("http");
const qrcode = require("qrcode-terminal");

const options = {
	hostname: "localhost",
	port: 3002,
	path: "/qr",
	method: "GET",
};

const req = https.request(options, (res) => {
	let data = "";

	res.on("data", (chunk) => {
		data += chunk;
	});

	res.on("end", () => {
		try {
			const response = JSON.parse(data);
			if (response.qr) {
				if (process.env.NODE_ENV === "development") {
					console.log("\n📱 WhatsApp QR Code - Scan with your phone:\n");
					console.log("1. Open WhatsApp on your phone");
					console.log("2. Go to Settings > Linked Devices");
					console.log('3. Tap "Link a Device"');
					console.log("4. Scan the QR code below:\n");
				}
				qrcode.generate(response.qr, { small: true });
				if (process.env.NODE_ENV === "development") {
					console.log("\n");
				}
			} else if (response.message) {
				if (process.env.NODE_ENV === "development") {
					console.log("✅", response.message);
				}
			} else {
				if (process.env.NODE_ENV === "development") {
					console.log("❌", response.error || "Unknown response");
				}
			}
		} catch (e) {
			if (process.env.NODE_ENV === "development") {
				console.log("Response:", data);
			}
		}
	});
});

req.on("error", (e) => {
	if (process.env.NODE_ENV === "development") {
		console.error("Error connecting to WhatsApp service:", e.message);
		console.log(
			"Make sure the service is running: cd backend/whatsapp-service && npm start"
		);
	}
});

req.end();
