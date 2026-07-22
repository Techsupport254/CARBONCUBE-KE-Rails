import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"

type GeneralUpdateProps = {
  fullname: string
  firstName: string
  userType: string
}

export default function GeneralUpdate({ fullname, firstName }: GeneralUpdateProps) {
  return (
    <EmailLayout preview="Important update from Carbon Cube Kenya">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Platform Update
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          An update from Carbon Cube Kenya
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {firstName || fullname},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          We wanted to share an important update with you. For more details, please visit your dashboard or contact our support team.
        </Text>

        <Text className="rsp-caption" style={{ margin: "10px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          Thank you for being part of Carbon Cube Kenya.
        </Text>
      </Section>
    </EmailLayout>
  )
}
