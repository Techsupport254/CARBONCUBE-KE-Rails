import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type ReviewRequestApprovedProps = {
	fullname: string
	firstName: string
	enterpriseName?: string | null
	reviewNotes?: string
	reviewedAt?: string
	dashboardUrl: string
	supportEmail: string
}

export default function ReviewRequestApproved({
	fullname,
	firstName,
	enterpriseName,
	reviewNotes,
	reviewedAt,
	dashboardUrl,
	supportEmail,
}: ReviewRequestApprovedProps) {
	const displayName = enterpriseName?.trim() || fullname || firstName || "Seller"

	return (
		<EmailLayout preview="Your Carbon Cube Kenya account review is approved">
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
					Review Approved
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
					Good news, {firstName || fullname}!
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
					We have completed the review of your account for {displayName}. Your account is now approved and fully restored on Carbon Cube Kenya.
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
					What this means:
				</Text>

				{[
					"Your ads are visible to buyers again.",
					"You can post, edit, and manage your shop normally.",
					"Your account is no longer under review.",
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
						<strong style={{ color: "#0f172a" }}>Review notes:</strong> {reviewNotes}
					</Text>
				)}

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
					Thank you for your patience. If you have any questions, contact us at{" "}
					<a
						href={`mailto:${supportEmail}`}
						style={{ color: "#22c55e", textDecoration: "none", fontWeight: 500 }}
					>
						{supportEmail}
					</a>
					.
				</Text>
			</Section>
		</EmailLayout>
	)
}
