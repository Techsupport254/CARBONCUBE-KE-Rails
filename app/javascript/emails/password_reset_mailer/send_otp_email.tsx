import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { CodeBlock } from "../_components/code_block"

type SendOtpEmailProps = {
  otp: string
  userEmail: string
  userType: string
}

export default function SendOtpEmail({ otp }: SendOtpEmailProps) {
  return (
    <EmailLayout preview="Your password reset code">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Password Reset
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Reset your password
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Use the code below to reset your password. This code expires shortly, so use it soon.
        </Text>

        <CodeBlock code={otp} label="Your password reset code" />

        <Text className="rsp-caption" style={{ margin: "10px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          If you did not request a password reset, you can safely ignore this email. Your account remains secure.
        </Text>
      </Section>
    </EmailLayout>
  )
}
