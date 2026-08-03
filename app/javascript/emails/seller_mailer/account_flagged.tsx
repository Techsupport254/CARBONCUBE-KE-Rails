import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type AccountFlaggedProps = {
	fullname: string
	firstName: string
	enterpriseName?: string | null
	flagNotes?: string
	reviewRequestUrl: string
	supportEmail: string
}

export default function AccountFlagged({
	fullname,
	firstName,
	enterpriseName,
	flagNotes,
	reviewRequestUrl,
	supportEmail,
}: AccountFlaggedProps) {
	const displayName = enterpriseName?.trim() || fullname || firstName || "Seller"

	return (
		<EmailLayout preview="Your Carbon Cube Kenya account has been flagged">
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
					Account Flagged
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
					Action required for {displayName}
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
					Your Carbon Cube Kenya seller account has been flagged by our review team. While your account is flagged, your ads are not visible to buyers.
				</Text>

				{flagNotes && (
					<Text
						className="rsp-body"
						style={{
							margin: "14px 0 0",
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
					"Review your shop information and ads for accuracy.",
					"Update any listings that do not meet our marketplace guidelines.",
					"Submit a review request once the issues are resolved.",
					"Our team will review your account within 24-48 hours.",
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
					<Button href={reviewRequestUrl}>
						Request Account Review
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
