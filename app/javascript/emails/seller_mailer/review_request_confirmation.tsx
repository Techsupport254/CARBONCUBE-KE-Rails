import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type ReviewRequestConfirmationProps = {
	fullname: string
	firstName: string
	enterpriseName?: string | null
	dashboardUrl: string
	supportEmail: string
}

export default function ReviewRequestConfirmation({
	fullname,
	firstName,
	enterpriseName,
	dashboardUrl,
	supportEmail,
}: ReviewRequestConfirmationProps) {
	const displayName = enterpriseName?.trim() || fullname || firstName || "Seller"

	return (
		<EmailLayout preview="Your Carbon Cube Kenya account review is in progress">
			<Section className="rsp-section" style={{ padding: "20px" }}>
				<Text
					className="rsp-eyebrow"
					style={{
						margin: "0 0 6px",
						fontSize: "11px",
						fontWeight: 600,
						color: "#22c55e",
						textTransform: "uppercase",
						letterSpacing: "0.5px",
					}}
				>
					Review Request Received
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
					Welcome back, {firstName || fullname}!
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
					We have received your account review request for {displayName}. Your account has been temporarily unflagged so you can continue posting, updating, and managing your ads without interruption while our team completes the review.
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
					What happens next:
				</Text>

				{[
					"Our team will review your account and ads within the next 24-48 hours.",
					"If everything looks good, your account stays unflagged.",
					"If we need more information, we will contact you directly.",
					"You can keep using your shop normally in the meantime.",
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
					<Button href={dashboardUrl}>
						Go to Seller Dashboard
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
					If you have any questions, reply to this email or contact our support team at{" "}
					<a
						href={`mailto:${supportEmail}`}
						style={{ color: "#22c55e", textDecoration: "none", fontWeight: 500 }}
					>
						{supportEmail}
					</a>
					. Thank you for being part of Carbon Cube Kenya.
				</Text>
			</Section>
		</EmailLayout>
	)
}
