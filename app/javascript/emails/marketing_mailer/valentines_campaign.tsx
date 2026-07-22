import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"

type ValentinesCampaignProps = {
  fullname: string
  enterpriseName: string
  adsCount: number
  totalClicks: number
  daysSinceLastAd: number
  tierName: string
  gender: string
  profilePicture: string
  topAdTitle?: string
  topAdClicks?: number
  dashboardUrl: string
}

export default function ValentinesCampaign({
  fullname,
  enterpriseName,
  adsCount,
  totalClicks,
  daysSinceLastAd,
  tierName,
  topAdTitle,
  topAdClicks,
  dashboardUrl,
}: ValentinesCampaignProps) {
  return (
    <EmailLayout preview="Your shop performance update">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Performance Update
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Your shop at a glance
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {fullname},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Here is a quick snapshot of {enterpriseName}'s performance on Carbon Cube Kenya.
        </Text>

        <InfoCard>
          <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
            <tr>
              <td style={{ fontSize: "13px", color: "#94a3b8", paddingBottom: "4px" }}>Active listings</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", textAlign: "right", paddingBottom: "4px" }}>{adsCount}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "13px", color: "#94a3b8", paddingBottom: "4px" }}>Total clicks</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", textAlign: "right", paddingBottom: "4px" }}>{totalClicks}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "13px", color: "#94a3b8", paddingBottom: "4px" }}>Current tier</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", textAlign: "right", paddingBottom: "4px" }}>{tierName}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "13px", color: "#94a3b8" }}>Days since last listing</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: daysSinceLastAd > 30 ? "#dc2626" : "#1e293b", textAlign: "right" }}>{daysSinceLastAd}</td>
            </tr>
          </table>
        </InfoCard>

        {topAdTitle && (
          <InfoCard label="Top performing listing">
            <Text style={{ margin: "0 0 4px", fontSize: "13px", fontWeight: 600, color: "#1e293b" }}>
              {topAdTitle}
            </Text>
            <Text style={{ margin: 0, fontSize: "11px", color: "#94a3b8" }}>
              {topAdClicks} clicks
            </Text>
          </InfoCard>
        )}

        <Section style={{ margin: "14px 0" }}>
          <Button href={dashboardUrl}>
            View Dashboard
          </Button>
        </Section>
      </Section>
    </EmailLayout>
  )
}
