import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"

type UserConfirmationProps = {
  name: string
  email: string
  accountType: string
  token: string
  timestamp: string
}

export default function UserConfirmation({
  name,
  accountType,
  timestamp,
}: UserConfirmationProps) {
  return (
    <EmailLayout preview="Your data deletion request has been received">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Deletion Request
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          We received your deletion request
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {name},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          We have received your request to permanently delete your {accountType} account and associated data. Our team will process this request and notify you once it is complete.
        </Text>

        <Text className="rsp-caption" style={{ margin: "8px 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          Request received on {timestamp}.
        </Text>

        <Text className="rsp-caption" style={{ margin: "10px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          If you did not request this deletion, please contact our support team immediately.
        </Text>
      </Section>
    </EmailLayout>
  )
}
