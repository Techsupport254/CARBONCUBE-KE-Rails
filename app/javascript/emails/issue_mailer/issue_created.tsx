import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"

type IssueCreatedProps = {
  userName: string
  issueNumber: string
  issueTitle: string
  issueDescription: string
  issueCategory: string
  issuePriority: string
  issueStatus: string
  submittedAt: string
  trackingUrl: string
}

export default function IssueCreated({
  userName,
  issueNumber,
  issueTitle,
  issueDescription,
  issueCategory,
  issuePriority,
  issueStatus,
  submittedAt,
  trackingUrl,
}: IssueCreatedProps) {
  return (
    <EmailLayout preview={`Issue ${issueNumber} submitted successfully`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Support Ticket
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Issue submitted successfully
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {userName},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Your support ticket has been created. We will notify you as the status changes.
        </Text>

        <InfoCard>
          <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "4px", width: "80px" }}>Ticket</td>
              <td style={{ fontSize: "13px", fontWeight: 700, color: "#1e293b", paddingBottom: "4px" }}>#{issueNumber}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "4px" }}>Title</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", paddingBottom: "4px" }}>{issueTitle}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "4px" }}>Category</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", paddingBottom: "4px" }}>{issueCategory}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "4px" }}>Priority</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", paddingBottom: "4px" }}>{issuePriority}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "4px" }}>Status</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#f59e0b", paddingBottom: "4px" }}>{issueStatus}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8" }}>Submitted</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b" }}>{submittedAt}</td>
            </tr>
          </table>
        </InfoCard>

        {issueDescription && (
          <InfoCard label="Description">
            <Text className="rsp-body" style={{ margin: 0, fontSize: "13px", color: "#334155", lineHeight: "20px", whiteSpace: "pre-wrap" }}>
              {issueDescription}
            </Text>
          </InfoCard>
        )}

        <Section style={{ margin: "14px 0" }}>
          <Button href={trackingUrl}>
            Track Issue
          </Button>
        </Section>
      </Section>
    </EmailLayout>
  )
}
