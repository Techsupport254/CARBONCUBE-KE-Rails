import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"

type CustomCommunicationProps = {
  fullname: string
  firstName: string
  subject: string
  message: string
  userType: string
}

export default function CustomCommunication({
  fullname,
  firstName,
  subject,
  message,
}: CustomCommunicationProps) {
  return (
    <EmailLayout preview={subject || "Message from Carbon Cube Kenya"}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Message
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          {subject || "A message from Carbon Cube Kenya"}
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {firstName || fullname},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px", whiteSpace: "pre-wrap" }}>
          {message}
        </Text>
      </Section>
    </EmailLayout>
  )
}
