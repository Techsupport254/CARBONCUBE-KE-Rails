import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type ShareShopFeatureProps = {
  fullname: string
  firstName: string
  dashboardUrl: string
}

export default function ShareShopFeature({ fullname, firstName, dashboardUrl }: ShareShopFeatureProps) {
  return (
    <EmailLayout preview="Share your shop with buyers everywhere">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Feature Highlight
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Share your shop with anyone
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {firstName || fullname},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          The <strong style={{ color: "#1e293b" }}>Share Shop</strong> feature on your seller dashboard lets you generate a direct link to your shop. It displays all your current listings in one place and can be shared across your preferred communication channels.
        </Text>

        <Section style={{ margin: "14px 0" }}>
          <Button href={dashboardUrl}>
            Access Share Shop
          </Button>
        </Section>

        <Text className="rsp-caption" style={{ margin: "10px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          For any questions or clarification, feel free to reach out.
        </Text>
      </Section>
    </EmailLayout>
  )
}
