import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { CodeBlock } from "../_components/code_block"

type SendOtpProps = {
  email: string
  code: string
  fullname: string
}

export default function SendOtp({ email, code, fullname }: SendOtpProps) {
  return (
    <EmailLayout preview="Your email verification code">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Email Verification
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Verify your email address
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {fullname},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Use the code below to verify your email address. This code expires shortly, so enter it soon.
        </Text>

        <CodeBlock code={code} label="Your verification code" />

        <Text className="rsp-caption" style={{ margin: "10px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          If you did not request this verification, you can safely ignore this email.
        </Text>
      </Section>
    </EmailLayout>
  )
}
