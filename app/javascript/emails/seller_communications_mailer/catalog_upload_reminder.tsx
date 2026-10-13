import { Section, Text, Link, Img } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"
import { Icon } from "../_components/icon"

type CatalogUploadReminderProps = {
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
	"Phones: Samsung Galaxy A15 128GB / 6GB RAM — 19.5k",
	"Laptops: HP EliteBook 840 G6 Core i5 16-256 SSD — 32k",
	"Hardware: Simba Cement 32.5R (50kg Bag) — 775/=",
	"Construction: Deformed Steel Rebar D12 (12m) — 1,115/=",
	"Auto Parts: Chloride Exide N70 Heavy Duty Battery — 14.5k",
	"TVs & Audio: TCL 55\" 4K UHD Smart Google TV — 46k",
	"Agriculture: Automatic 64-Egg Poultry Incubator — 12k",
	"Services: Workshop / Equipment Repair & Service — 800/=",
]

export default function CatalogUploadReminder({
	fullname,
	firstName,
	enterpriseName,
	dashboardUrl,
	whatsappUrl,
	supportEmail,
	supportPhone,
	bannerUrl = "https://res.cloudinary.com/dwrjceslk/image/upload/v1785482749/emails/ghybhzdpzvpw4ekmi3ct.png",
}: CatalogUploadReminderProps) {
	const shopName = enterpriseName?.trim() || fullname || "your shop"

	return (
		<EmailLayout preview="Friendly reminder: Send us your catalog — we'll upload your products for you">
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
					Reminder • Catalog Upload
				</Text>

				<Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
					Friendly reminder: We're ready to list your products
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 12px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
					Hi {firstName || fullname},
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 12px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
					Following up on our earlier message: <strong>{shopName}</strong> is live and visible on Carbon Cube Kenya, but you don't have active products listed yet. Active buyers are browsing daily — let's make sure they can find and buy from you!
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 12px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
					You don't have to spend your valuable time uploading them one by one. Just send us your price list or product details in whatever format you already have, and our operations team will format, categorize, and upload everything for you at <strong>no charge</strong>.
				</Text>

				{/* Accepted formats */}
				<InfoCard label="Send it however you have it">
					<table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
						{[
							["link", "Links to your website or existing social page"],
							["file-text", "Documents — PDF, Excel spreadsheets, or Word docs"],
							["image", "Photos — quick pictures of your products or price board"],
							["text", "Simple text message — a typed list of your items & prices"],
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
				<InfoCard label="Sample simple list">
					<table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
						<tr>
							<td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
								<Icon name="list" size={14} color="#f59e0b" />
							</td>
							<td style={{ fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
								A quick typed WhatsApp message works great — <strong style={{ color: "#0f172a" }}>item name, specs, and price</strong>:
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
						<strong>All categories welcome</strong> — computers & phones, auto parts & lubricants, hardware & construction, electronics & TVs, agriculture & tools, or professional services. Whether you have 3 products or 3,000, we'll list them all.
					</Text>
				</InfoCard>

				{/* 3 Steps */}
				<Text className="rsp-h2" style={{ margin: "18px 0 8px", fontSize: "14px", fontWeight: 700, color: "#0f172a" }}>
					3 Simple Steps:
				</Text>

				<table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
					{[
						["Send your catalog", "— click below to send via WhatsApp or reply to this email with photos or a list"],
						["Our team uploads it", "— we format, clean, categorize, and publish every item accurately"],
						["Start receiving inquiries", "— buyers find your storefront and contact you directly via call or WhatsApp"],
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

				<Section style={{ textAlign: "center", margin: "14px 0" }}>
					<Button href={whatsappUrl}>
						Send Catalog via WhatsApp
					</Button>
					{" "}
					<Button href={dashboardUrl} variant="secondary">
						Open Seller Dashboard
					</Button>
				</Section>

				{/* Help section */}
				<Text className="rsp-h2" style={{ margin: "18px 0 8px", fontSize: "14px", fontWeight: 700, color: "#0f172a" }}>
					Questions or need assistance?
				</Text>

				<Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
					Our merchant support team is available to assist you:
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
					Thank you for partnering with Carbon Cube Kenya.
				</Text>
			</Section>
		</EmailLayout>
	)
}
