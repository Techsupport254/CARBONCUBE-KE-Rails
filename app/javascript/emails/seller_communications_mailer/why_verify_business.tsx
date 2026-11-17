import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { Icon } from "../_components/icon"

type WhyVerifyBusinessProps = {
  fullname?: string
  firstName?: string
  contactUrl?: string
  whatsappUrl?: string
  whatsappNumber?: string
  dashboardUrl?: string
}

export default function WhyVerifyBusiness({
  fullname,
  firstName,
  contactUrl = "https://carboncube-ke.com/contact-us",
  whatsappUrl = "https://wa.me/254727854903",
  whatsappNumber = "+254 727 854 903",
  dashboardUrl = "https://carboncube-ke.com/seller/dashboard",
}: WhyVerifyBusinessProps) {
  const recipientName = firstName || fullname || "Seller"

  return (
    <EmailLayout preview="Why verify your business on Carbon Cube Kenya?">
      <Section className="rsp-section" style={{ padding: "24px 20px" }}>
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
          Seller Benefits
        </Text>

        <Text
          className="rsp-h1"
          style={{
            margin: "0 0 16px",
            fontSize: "18px",
            fontWeight: 700,
            color: "#0f172a",
            lineHeight: "24px",
          }}
        >
          Why verify your business on Carbon Cube Kenya?
        </Text>

        <Text
          className="rsp-body"
          style={{
            margin: "0 0 12px",
            fontSize: "14px",
            color: "#334155",
            lineHeight: "22px",
          }}
        >
          Hello {recipientName} 👋
        </Text>

        <Text
          className="rsp-body"
          style={{
            margin: "0 0 14px",
            fontSize: "14px",
            color: "#334155",
            lineHeight: "22px",
          }}
        >
          A verification badge helps build trust, makes your business stand out, and gives potential buyers more confidence when dealing with you.
        </Text>

        <Section style={{ margin: "14px 0", paddingLeft: "0" }}>
          <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
            <tbody>
              <tr>
                <td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
                  <Icon name="check" size={14} color="#f59e0b" />
                </td>
                <td
                  className="rsp-body"
                  style={{ fontSize: "13px", color: "#475569", lineHeight: "20px", paddingBottom: "8px" }}
                >
                  <strong>Verified badge</strong> on your shop and all product listings
                </td>
              </tr>
              <tr>
                <td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
                  <Icon name="check" size={14} color="#f59e0b" />
                </td>
                <td
                  className="rsp-body"
                  style={{ fontSize: "13px", color: "#475569", lineHeight: "20px", paddingBottom: "8px" }}
                >
                  <strong>Stand out</strong> among competing sellers in your category
                </td>
              </tr>
              <tr>
                <td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
                  <Icon name="check" size={14} color="#f59e0b" />
                </td>
                <td
                  className="rsp-body"
                  style={{ fontSize: "13px", color: "#475569", lineHeight: "20px" }}
                >
                  <strong>Higher buyer confidence</strong> and increased transaction rates
                </td>
              </tr>
            </tbody>
          </table>
        </Section>

        <Text
          className="rsp-body"
          style={{
            margin: "16px 0",
            fontSize: "14px",
            color: "#0f172a",
            fontWeight: 600,
            lineHeight: "22px",
          }}
        >
          Your products matter, but trust matters too!
        </Text>

        <Text
          className="rsp-body"
          style={{
            margin: "0 0 16px",
            fontSize: "14px",
            color: "#334155",
            lineHeight: "22px",
          }}
        >
          Reply to this message or tap below to have one of our agents help you verify your business.
        </Text>

        {/* Action Buttons */}
        <Section style={{ margin: "22px 0 12px" }}>
          <Button
            href={whatsappUrl}
            style={{
              backgroundColor: "#25D366",
              color: "#ffffff",
              padding: "10px 20px",
              fontSize: "13px",
              fontWeight: 600,
              borderRadius: "9999px",
              display: "inline-block",
              marginRight: "10px",
              marginBottom: "8px",
            }}
          >
            Verify via WhatsApp ({whatsappNumber})
          </Button>

          <Button
            href={contactUrl}
            variant="secondary"
            style={{
              padding: "10px 18px",
              fontSize: "13px",
              fontWeight: 600,
              borderRadius: "9999px",
              display: "inline-block",
              marginBottom: "8px",
            }}
          >
            Contact Support
          </Button>
        </Section>

        <Text
          className="rsp-body"
          style={{
            margin: "16px 0 0",
            fontSize: "13px",
            color: "#64748b",
            lineHeight: "20px",
          }}
        >
          🌐 <a href={contactUrl} style={{ color: "#f59e0b", textDecoration: "none", fontWeight: 600 }}>carboncube-ke.com/contact-us</a>
          <br /><br />
          Best regards,
          <br />
          <strong>The Carbon Cube Kenya Team</strong>
        </Text>
      </Section>
    </EmailLayout>
  )
}
