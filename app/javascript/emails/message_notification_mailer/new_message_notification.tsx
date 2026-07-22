import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"

type NewMessageNotificationProps = {
  recipientName: string
  senderName: string
  messageContent: string
  conversationUrl: string
  productContext?: string
}

export default function NewMessageNotification({
  recipientName,
  senderName,
  messageContent,
  conversationUrl,
  productContext,
}: NewMessageNotificationProps) {
  return (
    <EmailLayout preview={`New message from ${senderName}`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          New Message
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          You have a new message
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {recipientName},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          <strong style={{ color: "#1e293b" }}>{senderName}</strong> sent you a message on Carbon Cube Kenya.
        </Text>

        <InfoCard label="Message preview">
          <Text className="rsp-body" style={{ margin: 0, fontSize: "13px", color: "#334155", lineHeight: "20px" }}>
            {messageContent}
          </Text>
        </InfoCard>

        {productContext && (
          <InfoCard label="Regarding" backgroundColor="#fffbeb" borderColor="#fde68a">
            <Text className="rsp-body" style={{ margin: 0, fontSize: "13px", color: "#78350f", lineHeight: "20px" }}>
              {productContext}
            </Text>
          </InfoCard>
        )}

        <Section style={{ margin: "14px 0" }}>
          <Button href={conversationUrl}>
            View Conversation
          </Button>
        </Section>
      </Section>
    </EmailLayout>
  )
}
