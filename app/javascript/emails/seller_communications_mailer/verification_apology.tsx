import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type VerificationApologyProps = {
  fullname?: string
  firstName?: string
  contactUrl?: string
  whatsappUrl?: string
  whatsappNumber?: string
}

export default function VerificationApology({
  fullname,
  firstName,
  contactUrl = "https://carboncube-ke.com/contact-us",
  whatsappUrl = "https://wa.me/254727854903",
  whatsappNumber = "+254 727 854 903",
}: VerificationApologyProps) {
  const recipientName = firstName || fullname || "Seller"

  return (
    <EmailLayout preview="A personal note from Carbon Cube Kenya">
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
          Important Message
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
          A Personal Note from Carbon Cube Kenya
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
          Hello {recipientName},
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
          We’re reaching out personally to apologise for an experience you recently had with someone who approached you claiming to be a buyer, before later identifying themselves as a Carbon Cube Kenya agent seeking to verify your business.
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
          We understand that this was misleading and frustrating, and we’re truly sorry. This is not how we want our sellers to be treated, and we take your concerns seriously.
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
          At Carbon Cube Kenya, we value your business and the trust you place in us. We don’t want this experience to affect your confidence in our platform or your decision to continue using it. We are addressing the matter and working to ensure that our verification process is handled openly and honestly.
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
          We would appreciate the opportunity to make things right and reassure you that your trust matters to us.
        </Text>

        <Text
          className="rsp-body"
          style={{
            margin: "0 0 20px",
            fontSize: "14px",
            color: "#334155",
            lineHeight: "22px",
            fontWeight: 500,
          }}
        >
          Thank you for being part of Carbon Cube Kenya. We sincerely apologise for what happened.
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
            Chat on WhatsApp ({whatsappNumber})
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
            Contact Us Online
          </Button>
        </Section>

        <Text
          className="rsp-body"
          style={{
            margin: "12px 0 0",
            fontSize: "12px",
            color: "#64748b",
            lineHeight: "18px",
          }}
        >
          Need to talk directly? Reach our team on WhatsApp at{" "}
          <a href={whatsappUrl} style={{ color: "#25D366", fontWeight: 600, textDecoration: "none" }}>
            {whatsappNumber}
          </a>{" "}
          or visit{" "}
          <a href={contactUrl} style={{ color: "#f59e0b", fontWeight: 600, textDecoration: "none" }}>
            carboncube-ke.com/contact-us
          </a>
          .
        </Text>

        <Text
          className="rsp-body"
          style={{
            margin: "20px 0 0",
            fontSize: "13px",
            color: "#64748b",
            lineHeight: "20px",
          }}
        >
          Warm regards,
          <br />
          <strong>The Carbon Cube Kenya Team</strong>
        </Text>
      </Section>
    </EmailLayout>
  )
}
