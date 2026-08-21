import { Section, Text, Img, Row, Column, Hr } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type AdFlaggedProps = {
	fullname: string
	firstName: string
	enterpriseName?: string | null
	adId?: string | number
	adTitle: string
	adPrice?: string | null
	adCategory?: string | null
	adCondition?: string | null
	adImageUrl?: string | null
	flagReason?: string
	editAdUrl: string
	dashboardUrl: string
	supportEmail: string
}

export default function AdFlagged({
	fullname,
	firstName,
	enterpriseName,
	adId,
	adTitle,
	adPrice,
	adCategory,
	adCondition,
	adImageUrl,
	flagReason,
	editAdUrl,
	dashboardUrl,
	supportEmail,
}: AdFlaggedProps) {
	const displayName = enterpriseName?.trim() || fullname || firstName || "Partner"

	return (
		<EmailLayout preview={`Action needed for your listing "${adTitle}" on Carbon Cube Kenya`}>
			<Section className="rsp-section" style={{ padding: "24px 20px" }}>
				{/* Top Alert Badge */}
				<Text
					className="rsp-eyebrow"
					style={{
						margin: "0 0 8px",
						fontSize: "11px",
						fontWeight: 700,
						color: "#dc2626",
						textTransform: "uppercase",
						letterSpacing: "0.8px",
					}}
				>
					Listing Under Review
				</Text>

				{/* Header */}
				<Text
					className="rsp-h1"
					style={{
						margin: "0 0 12px",
						fontSize: "19px",
						fontWeight: 700,
						color: "#0f172a",
						lineHeight: "26px",
					}}
				>
					Action needed on your listing
				</Text>

				{/* Greeting */}
				<Text
					className="rsp-body"
					style={{
						margin: "0 0 10px",
						fontSize: "14px",
						color: "#334155",
						lineHeight: "22px",
					}}
				>
					Hi {displayName},
				</Text>

				<Text
					className="rsp-body"
					style={{
						margin: "0 0 16px",
						fontSize: "14px",
						color: "#475569",
						lineHeight: "22px",
					}}
				>
					During our routine quality and safety check, one of your product listings was flagged and temporarily hidden from public discovery. Please review the details below and update your listing to restore it to the marketplace.
				</Text>

				{/* Product Card Container */}
				<Section
					style={{
						backgroundColor: "#f8fafc",
						border: "1px solid #e2e8f0",
						borderRadius: "8px",
						padding: "14px 16px",
						margin: "16px 0",
					}}
				>
					<Text
						style={{
							margin: "0 0 8px",
							fontSize: "10px",
							fontWeight: 700,
							color: "#64748b",
							textTransform: "uppercase",
							letterSpacing: "0.6px",
						}}
					>
						Product Details
					</Text>

					<Row>
						{adImageUrl && (
							<Column style={{ width: "70px", verticalAlign: "top", paddingRight: "12px" }}>
								<Img
									src={adImageUrl}
									alt={adTitle}
									width="64"
									height="64"
									style={{
										borderRadius: "6px",
										objectFit: "cover",
										border: "1px solid #cbd5e1",
										display: "block",
									}}
								/>
							</Column>
						)}
						<Column style={{ verticalAlign: "top" }}>
							<Text
								style={{
									margin: "0 0 4px",
									fontSize: "15px",
									fontWeight: 700,
									color: "#0f172a",
									lineHeight: "20px",
								}}
							>
								{adTitle}
							</Text>

							{(adCategory || adCondition) && (
								<Text
									style={{
										margin: "0 0 4px",
										fontSize: "12px",
										color: "#64748b",
										lineHeight: "16px",
									}}
								>
									{adCategory && <span>Category: <strong>{adCategory}</strong></span>}
									{adCategory && adCondition && <span> • </span>}
									{adCondition && <span>Condition: <strong>{adCondition}</strong></span>}
								</Text>
							)}

							{adPrice && (
								<Text
									style={{
										margin: "2px 0 0",
										fontSize: "14px",
										fontWeight: 700,
										color: "#059669",
									}}
								>
									{adPrice}
								</Text>
							)}
						</Column>
					</Row>
				</Section>

				{/* Reason Callout Box */}
				{flagReason && (
					<Section
						style={{
							backgroundColor: "#fef2f2",
							border: "1px solid #fecaca",
							borderRadius: "8px",
							padding: "14px 16px",
							margin: "16px 0",
						}}
					>
						<Text
							style={{
								margin: "0 0 4px",
								fontSize: "11px",
								fontWeight: 700,
								color: "#991b1b",
								textTransform: "uppercase",
								letterSpacing: "0.5px",
							}}
						>
							Reason for Review
						</Text>
						<Text
							style={{
								margin: 0,
								fontSize: "13px",
								color: "#7f1d1d",
								lineHeight: "20px",
								fontWeight: 500,
							}}
						>
							{flagReason}
						</Text>
					</Section>
				)}

				{/* Resolution Checklist */}
				<Text
					style={{
						margin: "16px 0 8px",
						fontSize: "13px",
						fontWeight: 700,
						color: "#0f172a",
					}}
				>
					How to restore your listing:
				</Text>

				{[
					"Click the button below to open your listing editor.",
					"Replace any inappropriate, stock, or low-resolution images with real photos of your product.",
					"Ensure the price and description accurately match the physical item.",
					"Save your changes — your listing will automatically re-verify and go live.",
				].map((step, i) => (
					<Text
						key={i}
						style={{
							margin: "0 0 6px",
							fontSize: "13px",
							color: "#475569",
							lineHeight: "19px",
						}}
					>
						<strong style={{ color: "#0f172a" }}>{i + 1}.</strong> {step}
					</Text>
				))}

				{/* Primary Call to Action Button */}
				<Section style={{ margin: "20px 0 16px" }}>
					<Button href={editAdUrl || dashboardUrl}>
						Edit & Update Listing
					</Button>
				</Section>

				<Hr style={{ borderColor: "#e2e8f0", margin: "20px 0 14px" }} />

				{/* Support Contact */}
				<Text
					className="rsp-caption"
					style={{
						margin: 0,
						fontSize: "12px",
						color: "#94a3b8",
						lineHeight: "18px",
					}}
				>
					Need help or have questions regarding our seller policies? Reach out to our team at{" "}
					<a
						href={`mailto:${supportEmail}`}
						style={{ color: "#dc2626", textDecoration: "none", fontWeight: 600 }}
					>
						{supportEmail}
					</a>
					.
				</Text>
			</Section>
		</EmailLayout>
	)
}
