import { Section, Text, Link } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type WelcomeEmailProps = {
  name: string
  userType: string
  loginUrl: string
  dashboardUrl: string
  storefront_url?: string | null
  enterprise_name?: string | null
  supportEmail: string
  supportPhone: string
  timestamp: string
}

export default function WelcomeEmail({
  name,
  userType,
  loginUrl,
  dashboardUrl,
  storefront_url,
  enterprise_name,
  supportEmail,
  supportPhone,
}: WelcomeEmailProps) {
  const isSeller = userType === "seller"
  const shopName = enterprise_name || name

  return (
    <EmailLayout preview={isSeller ? `Welcome to Carbon Cube Kenya - Your Storefront & QR Standee Are Ready` : `Welcome to Carbon Cube Kenya - Your account is ready`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          {isSeller ? "Storefront Activated" : "Account Created"}
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "18px", fontWeight: 700, color: "#0f172a", lineHeight: "24px" }}>
          Welcome to Carbon Cube Kenya
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {name},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 10px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Your {isSeller ? "seller" : "buyer"} account is ready. You can now {isSeller ? "showcase products, receive orders, and connect with buyers across Kenya" : "browse products and connect with sellers across Kenya"}.
        </Text>

        {isSeller && storefront_url && (
          <>
            {/* Storefront URL Highlight */}
            <Section style={{ margin: "16px 0", padding: "16px", backgroundColor: "#f8fafc", borderRadius: "8px", border: "1px solid #e2e8f0" }}>
              <Text style={{ margin: "0 0 4px", fontSize: "12px", fontWeight: 600, color: "#64748b", textTransform: "uppercase" }}>
                Your Official Storefront Link
              </Text>
              <Text style={{ margin: "0 0 10px", fontSize: "13px", fontFamily: "monospace", fontWeight: 700, color: "#0f172a", wordBreak: "break-all" }}>
                {storefront_url}
              </Text>
              <Button href={storefront_url} style={{ backgroundColor: "#0f172a", color: "#ffffff", padding: "9px 16px", borderRadius: "6px", fontSize: "13px", fontWeight: 600, textDecoration: "none", display: "inline-block" }}>
                View Your Storefront
              </Button>
            </Section>

            {/* QR Standee Attachment Notice */}
            <Section style={{ margin: "16px 0", padding: "16px", backgroundColor: "#fffbeb", borderRadius: "8px", border: "1px solid #fde68a" }}>
              <Text style={{ margin: "0 0 6px", fontSize: "14px", fontWeight: 700, color: "#92400e" }}>
                📎 Your High-Res QR Standee is Attached
              </Text>
              <Text style={{ margin: "0 0 6px", fontSize: "13px", color: "#78350f", lineHeight: "19px" }}>
                We've automatically generated your official verified <strong>Merchant QR Standee</strong> and attached it to this email. You can:
              </Text>
              <Text style={{ margin: "0 0 3px", fontSize: "12px", color: "#78350f", lineHeight: "18px" }}>
                • <strong>Print & Place</strong> on your physical shop counter or display window.
              </Text>
              <Text style={{ margin: "0 0 3px", fontSize: "12px", color: "#78350f", lineHeight: "18px" }}>
                • <strong>Share</strong> directly with customers on WhatsApp and social media.
              </Text>
            </Section>
          </>
        )}

        {isSeller && (
          <Section style={{ margin: "16px 0", padding: "16px", backgroundColor: "#f8fafc", borderRadius: "8px", border: "1px solid #e2e8f0" }}>
            <Text style={{ margin: "0 0 8px", fontSize: "14px", fontWeight: 600, color: "#334155" }}>
              Need Help Uploading Products?
            </Text>
            <Text style={{ margin: "0 0 12px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
              You can easily send your product pictures, prices, and details to us via WhatsApp, and our dedicated support team will upload them for you!
            </Text>
            <Button href={`https://wa.me/254712990524`} style={{ backgroundColor: "#25D366", color: "#ffffff", padding: "9px 16px", borderRadius: "6px", fontSize: "13px", fontWeight: 600, textDecoration: "none", display: "inline-block" }}>
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
