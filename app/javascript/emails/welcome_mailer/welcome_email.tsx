import { Section, Text, Link } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type WelcomeEmailProps = {
  name: string
  userType: string
  loginUrl: string
  dashboardUrl: string
  supportEmail: string
  supportPhone: string
  timestamp: string
}

export default function WelcomeEmail({
  name,
  userType,
  loginUrl,
  dashboardUrl,
  supportEmail,
  supportPhone,
}: WelcomeEmailProps) {
  const isSeller = userType === "seller"

  return (
    <EmailLayout preview="Welcome to Carbon Cube Kenya - Your account is ready">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Account Created
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Welcome to Carbon Cube Kenya
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {name},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Your {isSeller ? "seller" : "buyer"} account is ready. You can now {isSeller ? "list products and start selling to buyers across Kenya" : "browse products and connect with sellers across Kenya"}.
        </Text>

        {isSeller && (
          <Section style={{ margin: "16px 0", padding: "16px", backgroundColor: "#f8fafc", borderRadius: "8px", border: "1px solid #e2e8f0" }}>
            <Text style={{ margin: "0 0 8px", fontSize: "15px", fontWeight: 600, color: "#334155" }}>
              Need Help Uploading Products?
            </Text>
            <Text style={{ margin: "0 0 12px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
              We understand you might be busy. You can easily send your product pictures, prices, and details to us via WhatsApp, and our dedicated support team will upload them for you!
            </Text>
            <Button href={`https://wa.me/254712990524`} style={{ backgroundColor: "#25D366", color: "#ffffff", padding: "10px 16px", borderRadius: "6px", fontSize: "14px", fontWeight: 600, textDecoration: "none", display: "inline-block" }}>
              Message Support on WhatsApp
            </Button>
          </Section>
        )}

        <Section style={{ margin: "14px 0" }}>
          <Button href={dashboardUrl}>
            Go to Dashboard
          </Button>
        </Section>

        <Text className="rsp-caption" style={{ margin: "10px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          Need help? Contact us at{" "}
          <Link href={`mailto:${supportEmail}`} style={{ color: "#f59e0b", textDecoration: "none", fontWeight: 500 }}>
            {supportEmail}
          </Link>{" "}
          or call {supportPhone}.
        </Text>
      </Section>
    </EmailLayout>
  )
}
