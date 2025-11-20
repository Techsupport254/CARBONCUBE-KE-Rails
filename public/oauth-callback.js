// OAuth callback handler - external script to comply with CSP
(function () {
	// Get data from JSON script tag (CSP-compliant)
	const dataElement = document.getElementById("oauth-callback-data");
	let data = {};

	if (dataElement) {
		try {
			data = JSON.parse(dataElement.textContent);
		} catch (e) {
			console.error("Failed to parse OAuth callback data:", e);
			data = {
				type: "GOOGLE_AUTH_ERROR",
				error: "Failed to parse callback data",
			};
		}
	}

	if (window.opener) {
		window.opener.postMessage(data, "*");
	}

	// Close the window after a short delay to ensure message is sent
	setTimeout(function () {
		window.close();
	}, 100);
})();
