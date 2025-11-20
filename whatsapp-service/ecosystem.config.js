// PM2 ecosystem configuration for WhatsApp service
module.exports = {
	apps: [
		{
			name: "whatsapp-service",
			script: "server.js",
			cwd: __dirname,
			instances: 1,
			exec_mode: "fork",
			env: {
				NODE_ENV: "production",
				WHATSAPP_SERVICE_PORT: 3002,
			},
			error_file: "./logs/whatsapp-error.log",
			out_file: "./logs/whatsapp-out.log",
			log_date_format: "YYYY-MM-DD HH:mm:ss Z",
			merge_logs: true,
			autorestart: true,
			max_restarts: 10,
			min_uptime: "10s",
			watch: false,
			ignore_watch: ["node_modules", ".wwebjs_auth", ".wwebjs_cache", "logs"],
		},
	],
};
