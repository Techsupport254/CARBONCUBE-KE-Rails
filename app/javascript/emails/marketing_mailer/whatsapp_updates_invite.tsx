import { Section, Text, Row, Column, Img } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"
import { Icon } from "../_components/icon"

type WhatsAppUpdatesInviteProps = {
  firstName: string
  fullname: string
  role: "buyer" | "seller"
  whatsappUrl: string
  dashboardUrl?: string
  reminderNumber?: number
  supportEmail?: string
  supportPhone?: string
  bannerUrl?: string
}

export default function WhatsAppUpdatesInvite({
  firstName,
  fullname,
  role,
  whatsappUrl,
  dashboardUrl,
  reminderNumber = 0,
  supportEmail = "support@carboncube-ke.com",
  supportPhone = "+254 712 990 524",
  bannerUrl = "https://res.cloudinary.com/dwrjceslk/image/upload/v1785482749/emails/ghybhzdpzvpw4ekmi3ct.png",
}: WhatsAppUpdatesInviteProps) {
  const isSeller = role === "seller"
  const isReminder = reminderNumber > 0

  const previewText = isReminder
    ? `${firstName}, quick reminder: get real-time Carbon Cube Kenya alerts on WhatsApp`
    : `${firstName}, stay updated in real time with Carbon Cube Kenya on WhatsApp`

  const headline = isReminder
    ? "Never miss an urgent inquiry or deal"
    : "Get real-time updates directly on WhatsApp"

  const intro = isReminder
    ? `Following up on our earlier note — we want to make sure you never miss high-priority updates. Connecting with Carbon Cube Kenya on WhatsApp takes just 2 seconds.`
    : `Stay ahead by receiving real-time alerts where you already spend your time. With WhatsApp updates, you get key platform notices instantly with zero delay.`

  const sellerPerks = [
    {
      icon: "message-square",
      title: "Instant Buyer Inquiries",
      desc: "Receive real-time alerts whenever active buyers message or request your contact details.",
    },
    {
      icon: "file-text",
      title: "Effortless Catalog Updates",
      desc: "Send price adjustments, new items, or photo updates straight to our operations team on WhatsApp.",
    },
    {
      icon: "trending-up",
      title: "Performance & Visibility Tips",
      desc: "Get curated insights on high-demand search trends and tips to accelerate your sales.",
    },
    {
      icon: "shield-check",
      title: "Direct Priority Support",
      desc: "Chat directly with our Nairobi merchant operations team whenever you need help.",
    },
  ]

  const buyerPerks = [
    {
      icon: "bell",
      title: "Price Drops & Fresh Deals",
      desc: "Be the first to know when products in your saved categories are discounted or newly listed.",
    },
    {
      icon: "shield-check",
      title: "Verified Seller Direct Connect",
      desc: "Get fast responses from genuine, field-verified sellers across Kenya.",
    },
    {
      icon: "package-check",
      title: "Order & Inquiry Tracking",
      desc: "Follow up on product availability and seller replies seamlessly on WhatsApp.",
    },
    {
      icon: "headphones",
      title: "Dedicated Buyer Support",
      desc: "Direct access to our customer care team to help resolve any issue quickly.",
    },
  ]

  const perks = isSeller ? sellerPerks : buyerPerks

  return (
    <EmailLayout preview={previewText}>
      <Section className="rsp-section" style={{ padding: "24px 20px" }}>
        {bannerUrl && (
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
        )}

        {/* Eyebrow */}
        <Text
          className="rsp-eyebrow"
          style={{
            margin: "0 0 6px",
            fontSize: "11px",
            fontWeight: 600,
            color: "#25D366",
            textTransform: "uppercase",
            letterSpacing: "0.5px",
          }}
        >
          {isReminder ? "Reminder • WhatsApp Updates" : "WhatsApp Updates"}
        </Text>

        {/* Headline */}
        <Text
          className="rsp-h1"
          style={{
            margin: "0 0 10px",
            fontSize: "18px",
            fontWeight: 700,
            color: "#0f172a",
            lineHeight: "24px",
          }}
        >
          {headline}
        </Text>

        {/* Greeting */}
        <Text
          className="rsp-body"
          style={{
            margin: "0 0 10px",
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
            margin: "0 0 16px",
            fontSize: "14px",
            color: "#475569",
            lineHeight: "21px",
          }}
        >
          {intro}
        </Text>

        {/* Perks Card */}
        <InfoCard label={isSeller ? "What you'll receive as a partner" : "What you'll receive as a shopper"}>
          <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
            <tbody>
              {perks.map((perk, i) => (
                <tr key={i}>
                  <td style={{ verticalAlign: "top", width: "28px", paddingTop: "4px" }}>
                    <Icon name={perk.icon} size={18} color="#25D366" />
                  </td>
                  <td style={{ paddingBottom: "12px", fontSize: "13px", lineHeight: "19px" }}>
                    <strong style={{ color: "#0f172a" }}>{perk.title}</strong>
                    <div style={{ color: "#64748b", marginTop: "2px" }}>{perk.desc}</div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </InfoCard>

        {/* CTA Section */}
        <Section style={{ textAlign: "center", margin: "22px 0 16px" }}>
          <Button
            href={whatsappUrl}
            style={{
              backgroundColor: "#25D366",
              color: "#ffffff",
              padding: "12px 26px",
              fontSize: "14px",
              fontWeight: 700,
              borderRadius: "9999px",
              display: "inline-block",
              boxShadow: "0 2px 4px rgba(37, 211, 102, 0.25)",
            }}
          >
            Connect on WhatsApp (1-Tap)
          </Button>

          {dashboardUrl && (
            <>
              {" "}
              <Button href={dashboardUrl} variant="secondary" style={{ padding: "12px 20px" }}>
                View Dashboard
              </Button>
            </>
          )}

          <Text
            style={{
              margin: "12px 0 0",
              fontSize: "12px",
              color: "#64748b",
              lineHeight: "18px",
            }}
          >
            Tapping opens WhatsApp with the keyword <strong style={{ color: "#0f172a" }}>START</strong> pre-filled.
            <br />
            Simply hit send to activate. You can opt out anytime by replying <strong style={{ color: "#0f172a" }}>STOP</strong>.
          </Text>
        </Section>

        {/* Need Help */}
        <Text
          className="rsp-h2"
          style={{
            margin: "20px 0 6px",
            fontSize: "13px",
            fontWeight: 700,
            color: "#0f172a",
          }}
        >
          Need assistance?
        </Text>
        <Text
          className="rsp-body"
          style={{
            margin: "0",
            fontSize: "12px",
            color: "#64748b",
            lineHeight: "18px",
          }}
        >
          Reach our team anytime via email at{" "}
          <strong style={{ color: "#0f172a" }}>{supportEmail}</strong> or call/WhatsApp at{" "}
          <strong style={{ color: "#0f172a" }}>{supportPhone}</strong>.
        </Text>
      </Section>
    </EmailLayout>
  )
}
