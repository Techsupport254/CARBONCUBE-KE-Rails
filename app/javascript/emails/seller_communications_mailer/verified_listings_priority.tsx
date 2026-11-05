import { Img, Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { Icon } from "../_components/icon"

type VerifiedListingsPriorityProps = {
  fullname?: string
  firstName?: string
  whatsappUrl?: string
  bannerUrl?: string
}

export default function VerifiedListingsPriority({
  fullname,
  firstName,
  whatsappUrl = "https://wa.me/254727854903",
  bannerUrl = "https://res.cloudinary.com/dwrjceslk/image/upload/v1793861019/email_banner_verified_listings.png",
}: VerifiedListingsPriorityProps) {
  const greetingName = firstName || fullname || "Seller"

  return (
    <EmailLayout preview="Verified listings get priority on Carbon Cube Kenya">
      <Section className="rsp-section" style={{ padding: "24px 20px" }}>
        <Img
          src={bannerUrl}
          width="100%"
          alt="Verified listings get priority on Carbon Cube Kenya"
          style={{
            display: "block",
            width: "100%",
            borderRadius: "6px",
            marginBottom: "20px",
            border: "0",
          }}
        />

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
          Quick question!
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
          Did you know verified listings get priority?
        </Text>

        <Text
          className="rsp-body"
          style={{
            margin: "0 0 10px",
            fontSize: "14px",
            color: "#475569",
            lineHeight: "21px",
          }}
        >
          Hi {greetingName},
        </Text>

        <Text
          className="rsp-body"
          style={{
            margin: "0 0 10px",
            fontSize: "14px",
            color: "#475569",
            lineHeight: "21px",
          }}
        >
          Show buyers your shop is 100% legit and safe to deal with — verified sellers earn more trust, more clicks, and more sales.
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
          Reply to this message and our team will get you verified today!
        </Text>

        <Section style={{ margin: "14px 0" }}>
          <Button href={whatsappUrl}>Get Verified Today</Button>
        </Section>

        <table role="presentation" cellPadding="0" cellSpacing="0" border={0}>
          <tr>
            <td style={{ verticalAlign: "middle", width: "20px" }}>
              <Icon name="check" size={13} color="#f59e0b" />
            </td>
            <td
              className="rsp-caption"
              style={{
                fontSize: "12px",
                color: "#64748b",
                lineHeight: "18px",
              }}
            >
              Prefer email? Just hit reply and we&apos;ll take it from there.
            </td>
          </tr>
        </table>
      </Section>
    </EmailLayout>
  )
}
