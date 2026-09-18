import { Section, Text } from "@react-email/components"
import { Markdown } from "@react-email/markdown"
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

        <Markdown
          markdownCustomStyles={{
            h2: { fontSize: "15px", fontWeight: 700, color: "#0f172a", margin: "18px 0 8px", lineHeight: "20px" },
            h3: { fontSize: "14px", fontWeight: 600, color: "#0f172a", margin: "14px 0 6px", lineHeight: "18px" },
            p: { fontSize: "14px", color: "#475569", lineHeight: "21px", margin: "0 0 10px" },
            li: { fontSize: "14px", color: "#475569", lineHeight: "21px", margin: "0 0 3px" },
            ul: { margin: "0 0 10px", paddingLeft: "18px" },
            ol: { margin: "0 0 10px", paddingLeft: "18px" },
            strong: { color: "#0f172a", fontWeight: 600 },
            a: { color: "#f59e0b", textDecoration: "underline" },
            blockquote: { borderLeft: "3px solid #e2e8f0", paddingLeft: "12px", margin: "10px 0", color: "#64748b", fontStyle: "italic" as const },
            hr: { border: "none", borderTop: "1px solid #e2e8f0", margin: "16px 0" },
          }}
        >
          {message}
        </Markdown>
      </Section>
    </EmailLayout>
  )
}
