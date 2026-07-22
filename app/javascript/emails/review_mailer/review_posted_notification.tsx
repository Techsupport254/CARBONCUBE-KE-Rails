import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"
import { Icon } from "../_components/icon"

type ReviewPostedNotificationProps = {
  sellerName: string
  buyerName: string
  adTitle: string
  rating: number
  reviewContent: string
  reviewUrl: string
}

export default function ReviewPostedNotification({
  sellerName,
  buyerName,
  adTitle,
  rating,
  reviewContent,
  reviewUrl,
}: ReviewPostedNotificationProps) {
  return (
    <EmailLayout preview={`New review on ${adTitle}`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          New Review
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          You received a new review
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {sellerName},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          <strong style={{ color: "#1e293b" }}>{buyerName}</strong> left a {rating}-star review on your product: <strong style={{ color: "#1e293b" }}>{adTitle}</strong>
        </Text>

        <InfoCard label="Review">
          <table role="presentation" cellPadding="0" cellSpacing="0" border={0} style={{ marginBottom: "6px" }}>
            <tr>
              {Array.from({ length: 5 }).map((_, i) => (
                <td key={i} style={{ paddingRight: "2px" }}>
                  <Icon name="star" size={14} color={i < rating ? "#f59e0b" : "#e2e8f0"} />
                </td>
              ))}
            </tr>
          </table>
          <Text className="rsp-body" style={{ margin: 0, fontSize: "13px", color: "#334155", lineHeight: "20px" }}>
            {reviewContent}
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
