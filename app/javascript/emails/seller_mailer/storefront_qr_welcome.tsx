import { Section, Text, Link } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type StorefrontQrWelcomeProps = {
	fullname: string
	firstName: string
	enterpriseName: string
	storefrontUrl: string
	qrStudioUrl: string
	supportEmail: string
	supportPhone: string
}

export default function StorefrontQrWelcome({
	fullname,
	firstName,
	enterpriseName,
	storefrontUrl,
	qrStudioUrl,
	supportEmail,
	supportPhone,
}: StorefrontQrWelcomeProps) {
	const shopTitle = enterpriseName?.trim() || fullname || "Your Shop"

	return (
		<EmailLayout preview={`Your Official QR Standee & Storefront Link for ${shopTitle}`}>
			<Section className="rsp-section" style={{ padding: "20px" }}>
				<Text
					className="rsp-eyebrow"
					style={{
						margin: "0 0 6px",
						fontSize: "11px",
						fontWeight: 600,
						color: "#f59e0b",
						textTransform: "uppercase",
						letterSpacing: "0.5px",
					}}
				>
					Official Storefront & QR Standee
				</Text>

				<Text
					className="rsp-h1"
					style={{
						margin: "0 0 8px",
						fontSize: "18px",
						fontWeight: 700,
						color: "#0f172a",
						lineHeight: "24px",
					}}
				>
					Congratulations, {shopTitle} is Live on Carbon Cube Kenya!
				</Text>

				<Text
					className="rsp-body"
					style={{
						margin: "0 0 8px",
						fontSize: "14px",
						color: "#475569",
						lineHeight: "22px",
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
						lineHeight: "22px",
					}}
				>
					Your official online storefront is ready to accept customer orders across Kenya. We have also automatically designed and attached your high-resolution <strong>Merchant QR Standee card</strong> to this email!
				</Text>

				{/* Storefront Link Highlight Card */}
				<Section
					style={{
						margin: "16px 0",
						padding: "16px",
						backgroundColor: "#f8fafc",
						borderRadius: "10px",
						border: "1px solid #e2e8f0",
					}}
				>
					<Text
						style={{
							margin: "0 0 6px",
							fontSize: "12px",
							fontWeight: 600,
							color: "#64748b",
							textTransform: "uppercase",
						}}
					>
						Your Storefront Web Link
					</Text>
					<Text
						style={{
							margin: "0 0 12px",
							fontSize: "14px",
							fontFamily: "monospace",
							fontWeight: 700,
							color: "#0f172a",
							wordBreak: "break-all",
						}}
					>
						{storefrontUrl}
					</Text>
					<Button href={storefrontUrl} style={{ backgroundColor: "#0f172a", color: "#ffffff", padding: "10px 18px", borderRadius: "6px", fontSize: "13px", fontWeight: 600, textDecoration: "none", display: "inline-block" }}>
						View Storefront
					</Button>
				</Section>

				{/* QR Standee Attachment Tips Card */}
				<Section
					style={{
						margin: "16px 0",
						padding: "16px",
						backgroundColor: "#fffbeb",
						borderRadius: "10px",
						border: "1px solid #fde68a",
					}}
				>
					<Text
						style={{
							margin: "0 0 8px",
							fontSize: "14px",
							fontWeight: 700,
							color: "#92400e",
						}}
					>
						📎 Your Printable QR Standee is Attached
					</Text>
					<Text
						style={{
							margin: "0 0 8px",
							fontSize: "13px",
							color: "#78350f",
							lineHeight: "20px",
						}}
					>
						Check the attachment on this email to download your high-resolution QR Standee. Here are great ways to use it:
					</Text>
					<Text
						style={{
							margin: "0 0 4px",
							fontSize: "12px",
							color: "#78350f",
							lineHeight: "18px",
						}}
					>
						• <strong>Print & Display</strong>: Place on your shop counter, billing desk, or window stand.
					</Text>
					<Text
						style={{
							margin: "0 0 4px",
							fontSize: "12px",
							color: "#78350f",
							lineHeight: "18px",
						}}
					>
						• <strong>Product Packaging</strong>: Include in delivery bags and customer receipts.
					</Text>
					<Text
						style={{
							margin: "0 0 8px",
							fontSize: "12px",
							color: "#78350f",
							lineHeight: "18px",
						}}
					>
						• <strong>Social Media</strong>: Share on your WhatsApp Status and Instagram stories.
					</Text>
				</Section>

				<Section style={{ margin: "18px 0" }}>
					<Button href={qrStudioUrl}>
						Customize in QR Studio
					</Button>
				</Section>

				<Text
					className="rsp-caption"
					style={{
						margin: "16px 0 0",
						fontSize: "12px",
						color: "#94a3b8",
						lineHeight: "18px",
					}}
				>
					Need assistance? Contact our merchant support team at{" "}
					<Link
						href={`mailto:${supportEmail}`}
						style={{ color: "#f59e0b", textDecoration: "none", fontWeight: 500 }}
					>
						{supportEmail}
					</Link>{" "}
					or call {supportPhone}.
				</Text>
			</Section>
		</EmailLayout>
	)
}
