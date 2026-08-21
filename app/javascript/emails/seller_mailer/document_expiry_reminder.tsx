import { Section, Text } from "@react-email/components"
import { Markdown } from "@react-email/markdown"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type DocumentExpiryReminderProps = {
  sellerName: string
  updateUrl: string
  customMessage?: string
}

export default function DocumentExpiryReminder({ sellerName, updateUrl, customMessage }: DocumentExpiryReminderProps) {
  return (
    <EmailLayout preview="Your verification documents are expiring soon">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Document Expiring
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          {customMessage ? "Action Required" : "Your documents expire soon"}
        </Text>

        {customMessage ? (
          <Markdown>
            {customMessage.replace(/\*(.*?)\*/g, '**$1**').replace(/(https?:\/\/[^\s]+)/g, '[$1]($1)')}
          </Markdown>
        ) : (
          <>
            <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
              Hi {sellerName},
            </Text>

            <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
              Your verification documents on Carbon Cube Kenya are set to expire in about one month. To keep your seller account active and maintain buyer trust, please upload updated documents.
            </Text>
          </>
        )}

        <Section style={{ margin: "14px 0" }}>
          <Button href={updateUrl}>
            Update Documents
          </Button>
        </Section>

        <Text className="rsp-caption" style={{ margin: "10px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          If you have already updated your documents, you can disregard this message.
        </Text>
      </Section>
    </EmailLayout>
  )
}
