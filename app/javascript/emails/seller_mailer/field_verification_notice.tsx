import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type Correction = {
	field: string
	oldValue?: string | null
	newValue?: string | null
}

type FieldVerificationNoticeProps = {
	sellerName: string
	corrected: boolean
	corrections?: Correction[]
	verifiedAt?: string | null
}

export default function FieldVerificationNotice({
	sellerName,
	corrected,
	corrections = [],
	verifiedAt,
}: FieldVerificationNoticeProps) {
	return (
		<EmailLayout preview="Our field team verified your shop details">
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
					Field Verification
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
					{corrected
						? "We updated your shop details"
						: "Your shop was verified"}
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
					Hi {sellerName},
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
					Our field team visited your shop{verifiedAt ? ` on ${verifiedAt}` : ""} and
					verified your Carbon Cube Kenya seller details.
					{corrected
						? " The following details were corrected based on what the team confirmed on-site:"
						: " All your shop details were confirmed as accurate."}
				</Text>

				{corrected && corrections.length > 0 && (
					<Section
						style={{
							margin: "14px 0",
							backgroundColor: "#f8fafc",
							border: "1px solid #e2e8f0",
							borderRadius: "8px",
							padding: "14px",
						}}
					>
						{corrections.map((c) => (
							<Text
								key={c.field}
								style={{
									margin: "0 0 8px",
									fontSize: "13px",
									color: "#475569",
									lineHeight: "19px",
								}}
							>
								<strong style={{ color: "#0f172a" }}>{c.field}:</strong>{" "}
								<span style={{ textDecoration: "line-through", color: "#94a3b8" }}>
									{c.oldValue || "—"}
								</span>{" "}
								→ <strong style={{ color: "#0f172a" }}>{c.newValue || "—"}</strong>
							</Text>
						))}
					</Section>
				)}

				<Text
					className="rsp-body"
					style={{
						margin: "0 0 14px",
						fontSize: "14px",
						color: "#475569",
						lineHeight: "21px",
					}}
				>
					If any of these changes look wrong, please update your profile or
					contact our support team right away.
				</Text>

				<Section style={{ margin: "14px 0" }}>
					<Button href="https://carboncube-ke.com/profile">
						Review My Profile
					</Button>
				</Section>
			</Section>
		</EmailLayout>
	)
}
