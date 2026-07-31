import { Section, Text, Img, Row, Column } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type AdCard = {
	title: string
	image?: string | null
	price?: number | string
	url: string
}

type AdVisibilityReminderProps = {
	fullname: string
	firstName: string
	enterpriseName?: string | null
	adsCount?: number
	lastActive?: string
	ads?: AdCard[]
	dashboardUrl: string
	supportEmail: string
}

export default function AdVisibilityReminder({
	fullname,
	firstName,
	enterpriseName,
	adsCount,
	lastActive,
	ads = [],
	dashboardUrl,
	supportEmail,
}: AdVisibilityReminderProps) {
	const displayName = enterpriseName?.trim() || fullname || firstName || "Seller"

	const formatPrice = (price?: number | string) => {
		if (!price || price === "0" || price === 0) return "Price on request"
		return `KSh ${Number(price).toLocaleString()}`
	}

	const leftAds = [ads[0], ads[2]].filter(Boolean) as AdCard[]
	const rightAds = [ads[1]].filter(Boolean) as AdCard[]

	const renderCard = (ad: AdCard, index: number) => (
		<a
			key={index}
			href={ad.url}
			style={{
				display: "block",
				textDecoration: "none",
				color: "inherit",
				marginBottom: "12px",
			}}
		>
			<Section
				style={{
					background: "#ffffff",
					border: "1px solid #e2e8f0",
					borderRadius: "8px",
					padding: "8px",
				}}
			>
				{ad.image ? (
					<Img
						src={ad.image}
						alt={ad.title}
						width="100%"
						style={{
							width: "100%",
							height: "auto",
							borderRadius: "6px",
							display: "block",
							border: "0",
							background: "#ffffff",
						}}
					/>
				) : (
					<div
						style={{
							width: "100%",
							minHeight: "90px",
							borderRadius: "6px",
							background: "#ffffff",
						}}
					/>
				)}
				<Text
					style={{
						margin: "8px 0 0",
						fontSize: "13px",
						fontWeight: 600,
						color: "#0f172a",
						lineHeight: "18px",
					}}
				>
					{ad.title}
				</Text>
				<Text
					style={{
						margin: "4px 0 0",
						fontSize: "13px",
						fontWeight: 700,
						color: "#3b82f6",
					}}
				>
					{formatPrice(ad.price)}
				</Text>
			</Section>
		</a>
	)

	return (
		<EmailLayout preview="Give your Carbon Cube Kenya shop a fresh boost">
			<Section className="rsp-section" style={{ padding: "20px" }}>
				<Text
					className="rsp-eyebrow"
					style={{
						margin: "0 0 6px",
						fontSize: "11px",
						fontWeight: 600,
						color: "#3b82f6",
						textTransform: "uppercase",
						letterSpacing: "0.5px",
					}}
				>
					Friendly Visibility Check-in
				</Text>

				<Text
					className="rsp-h1"
					style={{
						margin: "0 0 8px",
						fontSize: "17px",
						fontWeight: 700,
						color: "#0f172a",
						lineHeight: "22px",
					}}
				>
					{firstName || fullname}, a quick refresh can bring buyers back
				</Text>

				<Text
					className="rsp-body"
					style={{
						margin: "0 0 12px",
						fontSize: "14px",
						color: "#475569",
						lineHeight: "21px",
					}}
				>
					Hi {firstName || fullname},
				</Text>

				<Text
					className="rsp-body"
					style={{
						margin: "0 0 12px",
						fontSize: "14px",
						color: "#475569",
						lineHeight: "21px",
					}}
				>
					You already have {adsCount || "many"} ads on Carbon Cube Kenya — a great foundation for {displayName}. Because the marketplace favors recent activity, your shop has lost some visibility since your last activity on {lastActive || "a while ago"}.
				</Text>

				<Text
					className="rsp-h2"
					style={{
						margin: "14px 0 8px",
						fontSize: "14px",
						fontWeight: 700,
						color: "#0f172a",
					}}
				>
					Why refreshing helps
				</Text>

				{[
					"Fresh ads and updates rank higher in search.",
					"Buyers trust shops that look recently active.",
					"It takes just a few minutes to push your listings back up.",
				].map((item, i) => (
					<Text
						key={i}
						className="rsp-body"
						style={{
							margin: "0 0 4px",
							fontSize: "14px",
							color: "#475569",
							lineHeight: "20px",
						}}
					>
						• {item}
					</Text>
				))}

				{ads.length > 0 && (
					<Section style={{ marginTop: "20px" }}>
						<Text
							className="rsp-h2"
							style={{
								margin: "0 0 10px",
								fontSize: "14px",
								fontWeight: 700,
								color: "#0f172a",
							}}
						>
							Top ads from your shop
						</Text>

						<Row>
							<Column
								style={{
									width: "50%",
									padding: "0 6px 0 0",
									verticalAlign: "top",
								}}
							>
								{leftAds.map(renderCard)}
							</Column>
							<Column
								style={{
									width: "50%",
									padding: "0 0 0 6px",
									verticalAlign: "top",
								}}
							>
								{rightAds.map(renderCard)}
							</Column>
						</Row>
					</Section>
				)}

				<Section style={{ margin: "14px 0" }}>
					<Button href={dashboardUrl}>
						Add or Update Ads
					</Button>
				</Section>

				<Text
					className="rsp-caption"
					style={{
						margin: "10px 0 0",
						fontSize: "12px",
						color: "#94a3b8",
						lineHeight: "17px",
					}}
				>
					Need help? Reply to this email or reach our support team at{" "}
					<a
						href={`mailto:${supportEmail}`}
						style={{ color: "#3b82f6", textDecoration: "none", fontWeight: 500 }}
					>
						{supportEmail}
					</a>
					. We are rooting for you!
				</Text>
			</Section>
		</EmailLayout>
	)
}
