import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"

type StatusUpdatedProps = {
  userName: string
  issueNumber: string
  issueTitle: string
  oldStatus: string
  newStatus: string
  statusMessage: string
  updatedAt: string
  trackingUrl: string
}

export default function StatusUpdated({
  userName,
  issueNumber,
  issueTitle,
  oldStatus,
  newStatus,
  statusMessage,
  updatedAt,
  trackingUrl,
}: StatusUpdatedProps) {
  return (
    <EmailLayout preview={`Issue ${issueNumber} status updated to ${newStatus}`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Status Update
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Issue status updated
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {userName},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          The status of your issue <strong style={{ color: "#1e293b" }}>#{issueNumber}: {issueTitle}</strong> has been updated.
        </Text>

        <InfoCard>
          <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "4px", width: "80px" }}>Previous</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#94a3b8", paddingBottom: "4px" }}>{oldStatus}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "4px" }}>Current</td>
              <td style={{ fontSize: "13px", fontWeight: 700, color: "#f59e0b", paddingBottom: "4px" }}>{newStatus}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8" }}>Updated</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b" }}>{updatedAt}</td>
            </tr>
          </table>
        </InfoCard>

        <Text className="rsp-body" style={{ margin: "10px 0", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          {statusMessage}
        </Text>

        <Section style={{ margin: "14px 0" }}>
          <Button href={trackingUrl}>
            Track Issue
          </Button>
        </Section>
      </Section>
    </EmailLayout>
  )
}
