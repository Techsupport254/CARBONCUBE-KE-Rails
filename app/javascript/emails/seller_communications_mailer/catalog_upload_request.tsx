import { Section, Text, Link, Img } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"
import { Icon } from "../_components/icon"

type CatalogUploadRequestProps = {
	fullname: string
	firstName: string
	enterpriseName?: string | null
	dashboardUrl: string
	whatsappUrl: string
	supportEmail: string
	supportPhone: string
	bannerUrl?: string
}

const SAMPLE_LINES = [
	"HP ZBOOK 15 G8 i7 16-512 — 70k Only",
	"HP ZBOOK 14 G8 i7 32-512 — 75k Only",
	"HP 1040 G8 i7 32-512 X360 — 72k Only",
	"HP 1030 G8 i5 16-512 Touch — 56.5k Only",
	"X1 CARBON i7 16-512 11th Gen — 64k Only",
	"Dell Precision 7550 i7 16-512 — 71k Only",
	"Dell XPS 13 7390 i7 16-512 — 54k Only",
]

export default function CatalogUploadRequest({
	fullname,
	firstName,
	enterpriseName,
	dashboardUrl,
	whatsappUrl,
	supportEmail,
	supportPhone,
	bannerUrl = "https://res.cloudinary.com/dwrjceslk/image/upload/v1785482749/emails/ghybhzdpzvpw4ekmi3ct.png",
}: CatalogUploadRequestProps) {
	const shopName = enterpriseName?.trim() || fullname || "your shop"

	return (
		<EmailLayout preview="Send us your catalog — we'll upload it for you">
			<Section className="rsp-section" style={{ padding: "24px 20px" }}>
				<Img
					src={bannerUrl}
					width="100%"
					alt="Carbon Cube Kenya"
					style={{
						display: "block",
						width: "100%",
						borderRadius: "6px",
						marginBottom: "20px",
						border: "0",
					}}
				/>

				<Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
					Catalog Upload
				</Text>

				<Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
					Send us your catalog — we'll upload it for you
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 12px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
					Hi {firstName || fullname},
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 12px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
					{shopName} is live on Carbon Cube Kenya — now let's fill it with your products. Send us your catalog in whatever form you already have it and our team will upload everything for you.
				</Text>

				{/* Accepted formats */}
				<InfoCard label="Send it however you have it">
					<table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
						{[
							["link", "Links to your website or existing online catalog"],
							["file-text", "Documents — PDF, Excel, or Word"],
							["image", "Images — photos of your products or price list"],
							["text", "Just a text — a simple typed list of your products"],
						].map(([icon, label], i) => (
							<tr key={i}>
								<td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
									<Icon name={icon} size={14} color="#f59e0b" />
								</td>
								<td style={{ fontSize: "13px", color: "#475569", lineHeight: "20px", paddingBottom: "6px" }}>
									{label}
								</td>
							</tr>
						))}
					</table>
				</InfoCard>

				{/* Sample format */}
				<InfoCard label="Sample format">
					<table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
						<tr>
							<td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
								<Icon name="list" size={14} color="#f59e0b" />
							</td>
							<td style={{ fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
								If you prefer to type it out, a simple list works too — <strong style={{ color: "#0f172a" }}>product name, specs, and price</strong>:
							</td>
						</tr>
					</table>
					<Section
						style={{
							backgroundColor: "#0f172a",
							borderRadius: "6px",
							padding: "12px 14px",
							margin: "8px 0 4px",
						}}
					>
						{SAMPLE_LINES.map((line, i) => (
							<Text
								key={i}
								style={{
									margin: 0,
									fontSize: "11px",
									lineHeight: "19px",
									color: "#e2e8f0",
									fontFamily: "Menlo, Consolas, monospace",
									whiteSpace: "nowrap",
								}}
							>
								{line}
							</Text>
						))}
					</Section>
				</InfoCard>

				{/* Every category welcome */}
				<InfoCard backgroundColor="#f0fdf4" borderColor="#bbf7d0">
					<Text style={{ margin: 0, fontSize: "13px", color: "#166534", lineHeight: "20px" }}>
						<strong>Every category is welcome</strong> — phones & computers, TVs & electronics, auto parts, hardware & tools, filtration, agriculture, and services. Whether it's 5 products or 500, we'll get them listed.
					</Text>
				</InfoCard>

				{/* How it works */}
				<Text className="rsp-h2" style={{ margin: "18px 0 8px", fontSize: "14px", fontWeight: 700, color: "#0f172a" }}>
					How it works
				</Text>

				<table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
					{[
						["Send your catalog", "— reply to this email or WhatsApp us with a link, a document, or a typed list"],
						["We upload it", "— our team lists every item with correct categories and details"],
						["You start selling", "— your products go live and buyers can find them right away"],
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

				<Section style={{ textAlign: "center", margin: "10px 0 14px" }}>
					<Button href={whatsappUrl}>
						Send via WhatsApp
					</Button>
					{" "}
					<Button href={dashboardUrl} variant="secondary">
						Go to Dashboard
					</Button>
				</Section>

				{/* Help section */}
				<Text className="rsp-h2" style={{ margin: "18px 0 8px", fontSize: "14px", fontWeight: 700, color: "#0f172a" }}>
					Need help?
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
					If your catalog is large or in a special format, just send it over and we'll take care of it. You can reply to this email or reach us at:
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 4px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
					Phone / WhatsApp:{" "}
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
