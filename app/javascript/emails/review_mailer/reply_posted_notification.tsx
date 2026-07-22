import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"

type ReplyPostedNotificationProps = {
  buyerName: string
  sellerName: string
  adTitle: string
  sellerReply: string
  reviewUrl: string
}

export default function ReplyPostedNotification({
  buyerName,
  sellerName,
  adTitle,
  sellerReply,
  reviewUrl,
}: ReplyPostedNotificationProps) {
  return (
    <EmailLayout preview={`${sellerName} replied to your review`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Review Reply
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          The seller replied to your review
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {buyerName},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          <strong style={{ color: "#1e293b" }}>{sellerName}</strong> responded to your review on: <strong style={{ color: "#1e293b" }}>{adTitle}</strong>
        </Text>

        <InfoCard label="Seller's reply">
          <Text className="rsp-body" style={{ margin: 0, fontSize: "13px", color: "#334155", lineHeight: "20px" }}>
            {sellerReply}
          </Text>
        </InfoCard>

        <Section style={{ margin: "14px 0" }}>
          <Button href={reviewUrl}>
            View Review
          </Button>
        </Section>
      </Section>
    </EmailLayout>
  )
}
