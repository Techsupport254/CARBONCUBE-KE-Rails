import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { InfoCard } from "../_components/info_card"

type ContactFormProps = {
  name: string
  email: string
  phone: string
  subject: string
  message: string
  timestamp: string
}

export default function ContactForm({
  name,
  email,
  phone,
  subject,
  message,
  timestamp,
}: ContactFormProps) {
  return (
    <EmailLayout preview={`New contact form submission: ${subject}`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Contact Form
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          New contact form submission
        </Text>

        <InfoCard>
          <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "4px", width: "70px" }}>Name</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", paddingBottom: "4px" }}>{name}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "4px" }}>Email</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", paddingBottom: "4px" }}>{email}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "4px" }}>Phone</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", paddingBottom: "4px" }}>{phone || "Not provided"}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "4px" }}>Subject</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", paddingBottom: "4px" }}>{subject}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8" }}>Time</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b" }}>{timestamp}</td>
            </tr>
          </table>
        </InfoCard>

        <InfoCard label="Message">
          <Text className="rsp-body" style={{ margin: 0, fontSize: "13px", color: "#334155", lineHeight: "20px", whiteSpace: "pre-wrap" }}>
            {message}
          </Text>
        </InfoCard>
      </Section>
    </EmailLayout>
  )
}
