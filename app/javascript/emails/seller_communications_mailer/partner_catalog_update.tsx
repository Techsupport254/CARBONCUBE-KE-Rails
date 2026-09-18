import { Section, Text, Link } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"
import { Icon } from "../_components/icon"

type PartnerCatalogUpdateProps = {
	fullname: string
	firstName: string
	enterpriseName?: string | null
	totalAds: number
	withImages: number
	withoutImages: number
	shopUrl: string
	dashboardUrl: string
	username?: string | null
	tierName?: string | null
	email?: string | null
	supportEmail: string
	supportPhone: string
}

export default function PartnerCatalogUpdate({
	fullname,
	firstName,
	enterpriseName,
	totalAds,
	withImages,
	withoutImages,
	shopUrl,
	dashboardUrl,
	username,
	tierName,
	email,
	supportEmail,
	supportPhone,
}: PartnerCatalogUpdateProps) {
	const displayName = enterpriseName?.trim() || fullname || firstName || "Partner"

	return (
		<EmailLayout preview={`Your ${totalAds} products are live on Carbon Cube Kenya`}>
			<Section className="rsp-section" style={{ padding: "20px" }}>
				<Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
					Partner Catalog Update
				</Text>

				<Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
					Your {totalAds} products are live on Carbon Cube Kenya
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 12px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
					Hi {firstName || fullname},
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 12px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
					We are pleased to inform you that your entire {displayName} wholesale catalog has been successfully uploaded to Carbon Cube Kenya. Your storefront is now live and ready for buyers.
				</Text>

				{/* Catalog summary */}
				<InfoCard label="Your Catalog Summary">
					<table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
						<tr>
							<td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
								<Icon name="package" size={14} color="#f59e0b" />
							</td>
							<td style={{ fontSize: "13px", color: "#475569", lineHeight: "20px", paddingBottom: "6px" }}>
								<strong style={{ color: "#0f172a" }}>Total products listed:</strong> {totalAds}
							</td>
						</tr>
						<tr>
							<td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
								<Icon name="image" size={14} color="#22c55e" />
							</td>
							<td style={{ fontSize: "13px", color: "#475569", lineHeight: "20px", paddingBottom: "6px" }}>
								<strong style={{ color: "#0f172a" }}>Products with images:</strong> {withImages} (live and visible to buyers)
							</td>
						</tr>
						<tr>
							<td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
								<Icon name="image-off" size={14} color="#ef4444" />
							</td>
							<td style={{ fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
								<strong style={{ color: "#0f172a" }}>Products without images:</strong> {withoutImages} (currently hidden from buyers)
							</td>
						</tr>
					</table>
				</InfoCard>

				{withoutImages > 0 && (
					<>
						<InfoCard backgroundColor="#fef2f2" borderColor="#fecaca">
							<Text style={{ margin: 0, fontSize: "13px", color: "#991b1b", lineHeight: "20px", fontWeight: 600 }}>
								Important
							</Text>
							<Text style={{ margin: "4px 0 0", fontSize: "13px", color: "#7f1d1d", lineHeight: "20px" }}>
								The {withoutImages} listings without product images will not appear in search results or be visible to buyers until images are added. Products need at least one clear product photo to go live.
							</Text>
						</InfoCard>

						<Text className="rsp-h2" style={{ margin: "18px 0 8px", fontSize: "14px", fontWeight: 700, color: "#0f172a" }}>
							How to add missing images
						</Text>

						<table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
							{[
								["Sign in", `to your seller dashboard at ${dashboardUrl}`],
								["Go to My Ads", "to see all your listed products"],
								["Open any product", "missing an image and click Edit"],
								["Upload a photo", "(you can also use your phone camera to capture directly)"],
								["Save", "— the product will go live immediately"],
							].map(([bold, rest], i) => (
								<tr key={i}>
									<td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px", fontSize: "13px", fontWeight: 700, color: "#f59e0b" }}>
										{i + 1}.
									</td>
									<td style={{ fontSize: "13px", color: "#475569", lineHeight: "20px", paddingBottom: "6px" }}>
										<strong style={{ color: "#0f172a" }}>{bold}</strong> {rest}
									</td>
								</tr>
							))}
						</table>

						<InfoCard backgroundColor="#f0fdf4" borderColor="#bbf7d0">
							<Text style={{ margin: 0, fontSize: "13px", color: "#166534", lineHeight: "20px" }}>
								<strong>Tip:</strong> Good product photos significantly increase buyer enquiries. Use a clean background and show the product clearly from the front.
							</Text>
						</InfoCard>
					</>
				)}

				{/* Storefront section */}
				<Text className="rsp-h2" style={{ margin: "18px 0 8px", fontSize: "14px", fontWeight: 700, color: "#0f172a" }}>
					Your storefront
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
					Your shop is live at:{" "}
					<Link href={shopUrl} style={{ color: "#f59e0b", fontWeight: 600, textDecoration: "underline" }}>
						{shopUrl.replace("https://", "")}
					</Link>
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 14px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
					Share this link with your customers and on your social media channels to drive traffic to your products.
				</Text>

				<Section style={{ textAlign: "center", margin: "0 0 14px" }}>
					<Button href={dashboardUrl}>
						Go to Dashboard
					</Button>
					{" "}
					<Button href={shopUrl} variant="secondary">
						View Your Shop
					</Button>
				</Section>

				{/* Account details */}
				<InfoCard label="Your Account Details">
					<table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
						{tierName && (
							<tr>
								<td style={{ fontSize: "13px", color: "#64748b", lineHeight: "20px", paddingBottom: "4px", width: "120px" }}>Account tier</td>
								<td style={{ fontSize: "13px", color: "#0f172a", fontWeight: 600, lineHeight: "20px", paddingBottom: "4px" }}>{tierName}</td>
							</tr>
						)}
						{username && (
							<tr>
								<td style={{ fontSize: "13px", color: "#64748b", lineHeight: "20px", paddingBottom: "4px", width: "120px" }}>Username</td>
								<td style={{ fontSize: "13px", color: "#0f172a", fontWeight: 600, lineHeight: "20px", paddingBottom: "4px" }}>@{username}</td>
							</tr>
						)}
						{email && (
							<tr>
								<td style={{ fontSize: "13px", color: "#64748b", lineHeight: "20px", width: "120px" }}>Email</td>
								<td style={{ fontSize: "13px", color: "#0f172a", fontWeight: 600, lineHeight: "20px" }}>{email}</td>
							</tr>
						)}
					</table>
				</InfoCard>

				{/* Help section */}
				<Text className="rsp-h2" style={{ margin: "18px 0 8px", fontSize: "14px", fontWeight: 700, color: "#0f172a" }}>
					Need help?
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
					If you have product images in bulk (e.g. a shared drive or folder), send them to us and we will upload them for you. You can reply to this email or reach us at:
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 4px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
					Phone:{" "}
					<Link href={`tel:${supportPhone.replace(/\s/g, "")}`} style={{ color: "#f59e0b", textDecoration: "none", fontWeight: 500 }}>
						{supportPhone}
					</Link>
				</Text>
				<Text className="rsp-body" style={{ margin: "0 0 12px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
					Email:{" "}
					<Link href={`mailto:${supportEmail}`} style={{ color: "#f59e0b", textDecoration: "none", fontWeight: 500 }}>
						{supportEmail}
					</Link>
				</Text>

				<Text className="rsp-caption" style={{ margin: "10px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
					We look forward to a successful partnership.
				</Text>
			</Section>
		</EmailLayout>
	)
}
