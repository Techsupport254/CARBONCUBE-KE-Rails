import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type ReactivationEmailProps = {
  name: string
  reactivationUrl: string
  timestamp: string
  supportEmail: string
}

export default function ReactivationEmail({
  name,
  reactivationUrl,
  supportEmail,
}: ReactivationEmailProps) {
  return (
    <EmailLayout preview="Reactivate your Carbon Cube Kenya account">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Account Reactivation
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Reactivate your account
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {name},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          We received a request to reactivate your Carbon Cube Kenya account. Click the button below to proceed. This link will expire for security.
        </Text>

        <Section style={{ margin: "14px 0" }}>
          <Button href={reactivationUrl}>
            Reactivate Account
          </Button>
        </Section>

        <Text className="rsp-caption" style={{ margin: "10px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          If you did not request this, you can safely ignore this email. For help, contact{" "}
          <a href={`mailto:${supportEmail}`} style={{ color: "#f59e0b", textDecoration: "none", fontWeight: 500 }}>
            {supportEmail}
          </a>.
        </Text>
      </Section>
    </EmailLayout>
  )
}
