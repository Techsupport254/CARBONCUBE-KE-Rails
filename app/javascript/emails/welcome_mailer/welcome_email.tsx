import { Section, Text, Link, Hr } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type WelcomeEmailProps = {
  name: string
  userType: string
  loginUrl: string
  dashboardUrl: string
  storefront_url?: string | null
  enterprise_name?: string | null
  categories_url?: string | null
  how_to_shop_url?: string | null
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
  categories_url,
  how_to_shop_url,
  supportEmail,
  supportPhone,
}: WelcomeEmailProps) {
  const isSeller = userType === "seller"
  const shopName = enterprise_name || name

  return (
    <EmailLayout preview={isSeller ? `Welcome to Carbon Cube Kenya - Your Storefront & QR Standee Are Ready` : `Welcome to Carbon Cube Kenya - Your account is ready`}>
      <Section className="rsp-section" style={{ padding: "24px 20px 20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          {isSeller ? "Storefront Activated" : "Account Created"}
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 10px", fontSize: "20px", fontWeight: 700, color: "#0f172a", lineHeight: "26px" }}>
          Welcome to Carbon Cube Kenya
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 12px", fontSize: "14px", color: "#334155", lineHeight: "22px" }}>
          Hi {name},
        </Text>

        {isSeller ? (
          <Text className="rsp-body" style={{ margin: "0 0 16px", fontSize: "14px", color: "#475569", lineHeight: "22px" }}>
            Your seller account is ready. You can now showcase products, receive orders, and connect with buyers across Kenya.
          </Text>
        ) : (
          <>
            <Text className="rsp-body" style={{ margin: "0 0 14px", fontSize: "14px", color: "#475569", lineHeight: "22px" }}>
              Your buyer account is ready. You can now browse products from verified sellers, save your favorites, and connect directly with sellers across Kenya.
            </Text>

            <Text style={{ margin: "0 0 4px", fontSize: "13px", fontWeight: 700, color: "#0f172a" }}>
              What you can do now
            </Text>
            <Text style={{ margin: "0 0 3px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
              • <strong>Browse products and sellers</strong> — explore categories and verified storefronts across Kenya.
            </Text>
            <Text style={{ margin: "0 0 3px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
              • <strong>Save your favorites</strong> — keep track of products and sellers you love.
            </Text>
            <Text style={{ margin: "0 0 3px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
              • <strong>Message or call sellers</strong> — ask about availability, pricing, and pickup directly.
            </Text>
            <Text style={{ margin: "0 0 12px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
              • <strong>Read seller reviews</strong> — see what other buyers say before you reach out.
            </Text>

            {categories_url && (
              <Section style={{ margin: "10px 0 4px" }}>
                <Button href={categories_url} variant="secondary">
                  Explore Categories
                </Button>
              </Section>
            )}

            {how_to_shop_url && (
              <Text style={{ margin: "10px 0 0", fontSize: "12px", color: "#64748b", lineHeight: "18px" }}>
                New to Carbon? <Link href={how_to_shop_url} style={{ color: "#f59e0b", textDecoration: "none", fontWeight: 500 }}>See how to shop</Link>.
              </Text>
            )}
          </>
        )}

        {isSeller && storefront_url && (
          <>
            <Hr style={{ borderColor: "#e2e8f0", margin: "18px 0 14px" }} />

            <Text style={{ margin: "0 0 4px", fontSize: "11px", fontWeight: 600, color: "#64748b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
              Your Official Storefront Link
            </Text>
            <Text style={{ margin: "0 0 10px", fontSize: "13px", fontFamily: "monospace", fontWeight: 700, color: "#0f172a", wordBreak: "break-all" }}>
              {storefront_url}
            </Text>
            <Section style={{ margin: "0 0 14px" }}>
              <Button href={storefront_url} style={{ backgroundColor: "#0f172a", color: "#ffffff", padding: "9px 16px", borderRadius: "9999px", fontSize: "13px", fontWeight: 600, textDecoration: "none", display: "inline-block" }}>
                View Your Storefront
              </Button>
            </Section>

            <Text style={{ margin: "0 0 4px", fontSize: "13px", fontWeight: 700, color: "#92400e" }}>
              Your High-Res QR Standee is Attached
            </Text>
            <Text style={{ margin: "0 0 3px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
              We've generated your official verified <strong>Merchant QR Standee</strong> and attached it to this email. Print it for your counter, or share it with customers on WhatsApp and social media.
            </Text>
          </>
        )}

        {isSeller && (
          <>
            <Hr style={{ borderColor: "#e2e8f0", margin: "18px 0 14px" }} />
            <Text style={{ margin: "0 0 10px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
              Need help uploading products? Send your pictures, prices, and details to us on WhatsApp and our support team will list them for you.
            </Text>
            <Section style={{ margin: "0 0 4px" }}>
              <Button href="https://wa.me/254712990524" style={{ backgroundColor: "#25D366", color: "#ffffff", padding: "9px 16px", borderRadius: "9999px", fontSize: "13px", fontWeight: 600, textDecoration: "none", display: "inline-block" }}>
                Message Support on WhatsApp
              </Button>
            </Section>
          </>
        )}

        <Section style={{ margin: "18px 0 10px" }}>
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
