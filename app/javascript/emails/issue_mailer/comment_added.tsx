import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"

type CommentAddedProps = {
  userName: string
  issueNumber: string
  issueTitle: string
  commentContent: string
  commenterName: string
  commenterType: string
  commentedAt: string
  trackingUrl: string
}

export default function CommentAdded({
  userName,
  issueNumber,
  issueTitle,
  commentContent,
  commenterName,
  commenterType,
  commentedAt,
  trackingUrl,
}: CommentAddedProps) {
  return (
    <EmailLayout preview={`New comment on issue ${issueNumber}`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          New Comment
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          New comment on your issue
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {userName},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          <strong style={{ color: "#1e293b" }}>{commenterName}</strong> ({commenterType}) added a comment on issue <strong style={{ color: "#1e293b" }}>#{issueNumber}: {issueTitle}</strong>.
        </Text>

        <InfoCard label="Comment">
          <Text className="rsp-body" style={{ margin: 0, fontSize: "13px", color: "#334155", lineHeight: "20px", whiteSpace: "pre-wrap" }}>
            {commentContent}
          </Text>
        </InfoCard>

        <Text className="rsp-caption" style={{ margin: "8px 0", fontSize: "12px", color: "#94a3b8" }}>
          {commentedAt}
        </Text>

        <Section style={{ margin: "14px 0" }}>
          <Button href={trackingUrl}>
            View Issue
          </Button>
        </Section>
      </Section>
    </EmailLayout>
  )
}
