import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type ReactivationConfirmationProps = {
	fullname: string
	firstName: string
	enterpriseName?: string | null
	dashboardUrl: string
	supportEmail: string
}

export default function ReactivationConfirmation({
	fullname,
	firstName,
	enterpriseName,
	dashboardUrl,
	supportEmail,
}: ReactivationConfirmationProps) {
	const displayName = enterpriseName?.trim() || fullname || firstName || "Seller"

	return (
		<EmailLayout preview="Your Carbon Cube Kenya account has been reactivated">
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
					Account Reactivated
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
					Your Carbon Cube Kenya account for {displayName} has been
					reactivated based on your request. You can now log in and continue
					posting your ads, managing your shop, and reaching buyers.
				</Text>

				<Text
					className="rsp-body"
					style={{
						margin: "0 0 14px",
						fontSize: "14px",
						color: "#475569",
						lineHeight: "21px",
					}}
				>
					Click the button below to visit your seller dashboard.
				</Text>

				<Section style={{ margin: "14px 0" }}>
					<Button href={dashboardUrl}>
						Go to Dashboard
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
					If you have any questions, please reach out to our support team at{" "}
					<a
						href={`mailto:${supportEmail}`}
						style={{ color: "#f59e0b", textDecoration: "none", fontWeight: 500 }}
					>
						{supportEmail}
					</a>
					. We are glad to have you back!
				</Text>
			</Section>
		</EmailLayout>
	)
}
