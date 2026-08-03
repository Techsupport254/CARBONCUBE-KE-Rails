import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type AdFlaggedProps = {
	fullname: string
	firstName: string
	enterpriseName?: string | null
	adTitle: string
	adUrl?: string
	flagNotes?: string
	dashboardUrl: string
	supportEmail: string
}

export default function AdFlagged({
	fullname,
	firstName,
	enterpriseName,
	adTitle,
	adUrl,
	flagNotes,
	dashboardUrl,
	supportEmail,
}: AdFlaggedProps) {
	const displayName = enterpriseName?.trim() || fullname || firstName || "Seller"

	return (
		<EmailLayout preview={`Your ad "${adTitle}" has been flagged on Carbon Cube Kenya`}>
			<Section className="rsp-section" style={{ padding: "20px" }}>
				<Text
					className="rsp-eyebrow"
					style={{
						margin: "0 0 6px",
						fontSize: "11px",
						fontWeight: 600,
						color: "#ef4444",
						textTransform: "uppercase",
						letterSpacing: "0.5px",
					}}
				>
					Ad Flagged
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
					Your ad needs attention, {firstName || fullname}
				</Text>

				<Text
					className="rsp-body"
					style={{
						margin: "0 0 6px",
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
						margin: "0 0 6px",
						fontSize: "14px",
						color: "#475569",
						lineHeight: "21px",
					}}
				>
					One of your ads on Carbon Cube Kenya has been flagged by our review team and is no longer visible to buyers.
				</Text>

				<Text
					className="rsp-body"
					style={{
						margin: "14px 0 0",
						fontSize: "14px",
						color: "#0f172a",
						lineHeight: "21px",
						fontWeight: 600,
					}}
				>
					{adTitle}
				</Text>

				{flagNotes && (
					<Text
						className="rsp-body"
						style={{
							margin: "10px 0 0",
							fontSize: "14px",
							color: "#475569",
							lineHeight: "21px",
						}}
					>
						<strong style={{ color: "#0f172a" }}>Reason for flagging:</strong>{" "}
						{flagNotes}
					</Text>
				)}

				<Text
					className="rsp-body"
					style={{
						margin: "14px 0 6px",
						fontSize: "14px",
						color: "#475569",
						lineHeight: "21px",
					}}
				>
					What you can do:
				</Text>

				{[
					"Review the ad details and make the requested changes.",
					"Update images, description, price, or category if needed.",
					"Save the changes to remove the flag.",
					"Contact support if you believe this was done in error.",
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

				<Section style={{ margin: "14px 0" }}>
					<Button href={adUrl || dashboardUrl}>
						Go to Ad
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
					Need help? Contact us at{" "}
					<a
						href={`mailto:${supportEmail}`}
						style={{ color: "#ef4444", textDecoration: "none", fontWeight: 500 }}
					>
						{supportEmail}
					</a>
					.
				</Text>
			</Section>
		</EmailLayout>
	)
}
