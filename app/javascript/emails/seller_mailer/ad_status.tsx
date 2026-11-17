import { Section, Text, Img, Hr } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"

type AdStatusProps = {
	fullname: string
	firstName: string
	enterpriseName?: string | null
	adId?: string | number
	adTitle: string
	adPrice?: string | null
	adCategory?: string | null
	adCondition?: string | null
	adImageUrl?: string | null
	/** e.g. "Featured", "No longer featured", "Restored", "Removed" */
	statusLabel: string
	/** Short explanation shown under the product details. */
	statusMessage: string
	/** Accent color for the status rule — defaults to brand amber. */
	accentColor?: string
	ctaLabel?: string
	ctaUrl: string
	dashboardUrl: string
	supportEmail: string
}

export default function AdStatus({
	fullname,
	firstName,
	enterpriseName,
	adId,
	adTitle,
	adPrice,
	adCategory,
	adCondition,
	adImageUrl,
	statusLabel,
	statusMessage,
	accentColor = "#f59e0b",
	ctaLabel = "View listing",
	ctaUrl,
	dashboardUrl,
	supportEmail,
}: AdStatusProps) {
	const displayName = enterpriseName?.trim() || fullname || firstName || "Partner"
	const meta = [adCategory, adCondition].filter(Boolean).join(" • ")

	return (
		<EmailLayout preview={`${statusLabel}: "${adTitle}" on Carbon Cube Kenya`}>
			<Section className="rsp-section" style={{ padding: "24px 20px" }}>
				<Text
					className="rsp-eyebrow"
					style={{
						margin: "0 0 8px",
						fontSize: "11px",
						fontWeight: 700,
						color: accentColor,
						textTransform: "uppercase",
						letterSpacing: "0.5px",
					}}
				>
					{statusLabel}
				</Text>

				<Text
					className="rsp-h1"
					style={{ margin: "0 0 8px", fontSize: "20px", fontWeight: 700, color: "#0f172a", lineHeight: "26px" }}
				>
					{statusMessage}
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 16px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
					Hi {firstName || displayName},
				</Text>

				{adImageUrl ? (
					<Img
						src={adImageUrl}
						alt={adTitle}
						width="120"
						style={{ borderRadius: "10px", margin: "0 0 12px", display: "block" }}
					/>
				) : null}

				<InfoCard label="Listing">
					<Text style={{ margin: 0, fontSize: "14px", fontWeight: 600, color: "#0f172a", lineHeight: "20px" }}>
						{adTitle}
					</Text>
					{(adPrice || meta) && (
						<Text style={{ margin: "4px 0 0", fontSize: "13px", color: "#64748b", lineHeight: "19px" }}>
							{[adPrice, meta].filter(Boolean).join("  •  ")}
						</Text>
					)}
				</InfoCard>

				<Hr style={{ border: "none", borderTop: "1px solid #e2e8f0", margin: "20px 0" }} />

				<Button href={ctaUrl}>{ctaLabel}</Button>

				<Text className="rsp-body" style={{ margin: "16px 0 0", fontSize: "13px", color: "#64748b", lineHeight: "19px" }}>
					Questions? Reply to this email or reach us at{" "}
					<a href={`mailto:${supportEmail}`} style={{ color: "#f59e0b" }}>{supportEmail}</a>.
				</Text>
				<Text className="rsp-body" style={{ margin: "6px 0 0", fontSize: "12px", color: "#94a3b8" }}>
					Manage all your listings from your{" "}
					<a href={dashboardUrl} style={{ color: "#f59e0b" }}>seller dashboard</a>.
				</Text>
			</Section>
		</EmailLayout>
	)
}
