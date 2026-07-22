import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"

type SellerGrowthInitiativeProps = {
  fullname: string
  firstName: string
  enterpriseName: string
  adsCount: number
  tierName: string
  dashboardUrl: string
}

export default function SellerGrowthInitiative({
  fullname,
  firstName,
  enterpriseName,
  adsCount,
  tierName,
  dashboardUrl,
}: SellerGrowthInitiativeProps) {
  return (
    <EmailLayout preview="Tips to grow your sales on Carbon Cube Kenya">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Growth Initiative
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Grow your sales on Carbon Cube Kenya
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {firstName || fullname},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Here are practical strategies to help you get more visibility and increase your sales on the platform.
        </Text>

        <InfoCard label="Your account at a glance">
          <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
            <tr>
              <td style={{ fontSize: "13px", color: "#94a3b8", paddingBottom: "4px" }}>Shop</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", textAlign: "right", paddingBottom: "4px" }}>{enterpriseName}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "13px", color: "#94a3b8", paddingBottom: "4px" }}>Active listings</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", textAlign: "right", paddingBottom: "4px" }}>{adsCount}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "13px", color: "#94a3b8" }}>Current tier</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", textAlign: "right" }}>{tierName}</td>
            </tr>
          </table>
        </InfoCard>

        <Text className="rsp-body" style={{ margin: "10px 0 4px", fontSize: "14px", fontWeight: 600, color: "#1e293b" }}>
          Three ways to grow
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 4px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
          <strong style={{ color: "#1e293b" }}>1. Add more listings.</strong> Sellers with 10+ listings receive 3x more buyer inquiries.
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 4px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
          <strong style={{ color: "#1e293b" }}>2. Use high-quality photos.</strong> Listings with clear, well-lit images get more clicks.
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
          <strong style={{ color: "#1e293b" }}>3. Respond quickly.</strong> Fast replies to buyer messages build trust and close more sales.
        </Text>

        <Section style={{ margin: "14px 0" }}>
          <Button href={dashboardUrl}>
            Go to Dashboard
          </Button>
        </Section>
      </Section>
    </EmailLayout>
  )
}
