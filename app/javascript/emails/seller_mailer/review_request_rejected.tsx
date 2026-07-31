import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type ReviewRequestRejectedProps = {
	fullname: string
	firstName: string
	enterpriseName?: string | null
	reviewNotes?: string
	reviewedAt?: string
	contactUrl: string
	supportEmail: string
}

export default function ReviewRequestRejected({
	fullname,
	firstName,
	enterpriseName,
	reviewNotes,
	reviewedAt,
	contactUrl,
	supportEmail,
}: ReviewRequestRejectedProps) {
	const displayName = enterpriseName?.trim() || fullname || firstName || "Seller"

	return (
		<EmailLayout preview="Your Carbon Cube Kenya account review has been updated">
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
					Review Outcome
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
					We need more clarity, {firstName || fullname}
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
					Our team has reviewed your account for {displayName}. Unfortunately, we were unable to approve the review at this time because the account still does not meet our current guidelines.
				</Text>

				{reviewNotes && (
					<Text
						className="rsp-body"
						style={{
							margin: "14px 0 0",
							fontSize: "14px",
							color: "#475569",
							lineHeight: "21px",
						}}
					>
						<strong style={{ color: "#0f172a" }}>Reason for the decision:</strong> {reviewNotes}
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
					What you can do next:
				</Text>

				{[
					"Review the seller guidelines and update your shop information.",
					"Make sure product details, prices, and images are accurate.",
					"Reach out to support if you believe this decision was made in error.",
					"You can submit a new review request once the issues are resolved.",
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

				{reviewedAt && (
					<Text
						className="rsp-caption"
						style={{
							margin: "10px 0 0",
							fontSize: "12px",
							color: "#94a3b8",
							lineHeight: "17px",
						}}
					>
						Reviewed on {reviewedAt}
					</Text>
				)}

				<Section style={{ margin: "14px 0" }}>
					<Button href={contactUrl}>
						Contact Support
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
					Need help? Reach our support team at{" "}
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
