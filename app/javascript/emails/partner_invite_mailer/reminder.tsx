import { Section, Text } from "@react-email/components"
import { Markdown } from "@react-email/markdown"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"

type ReminderProps = {
  stage: string // "reminder_1" | "reminder_2"
  inviteKind: string
  roleLabel: string
  inviteeName: string
  partnerName?: string | null
  joinUrl: string
  expiresAt?: string | null
  benefits?: string | null
  benefitsHeading?: string | null
  supportEmail: string
  supportPhone: string
}

export default function Reminder({
  stage,
  inviteKind,
  roleLabel,
  inviteeName,
  partnerName,
  joinUrl,
  expiresAt,
  benefits,
  benefitsHeading,
  supportEmail,
  supportPhone,
}: ReminderProps) {
  const isFinal = stage === "reminder_2"
  const role = roleLabel.charAt(0).toUpperCase() + roleLabel.slice(1)
  const isNewAccount = inviteKind === "new_account"

  return (
    <EmailLayout
      preview={isFinal ? "Your Carbon Cube invite expires soon" : `Reminder — your ${roleLabel} invitation is waiting`}
    >
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: isFinal ? "#dc2626" : "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          {isFinal ? "Final Reminder" : "Reminder"}
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          {isFinal ? "Your invite expires soon" : "Your invitation is still waiting"}
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hello {inviteeName},
        </Text>

        {isFinal ? (
          <Text className="rsp-body" style={{ margin: "0 0 14px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
            Your Carbon Cube Kenya {roleLabel} invitation{partnerName ? ` (${partnerName})` : ""} expires
            {expiresAt ? ` on ${expiresAt}` : " shortly"}. After that the link stops working and you'll need a new invite from our team — this is the last reminder we'll send.
          </Text>
        ) : (
          <Text className="rsp-body" style={{ margin: "0 0 14px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
            Just a nudge — your Carbon Cube Kenya {roleLabel} invitation{partnerName ? ` (${partnerName})` : ""} is still open.
            {isNewAccount
              ? " Your seller account is ready and waiting — it only takes a minute to set your password and get started."
              : " Accept it to activate the partnership and start receiving pricing and important updates."}
          </Text>
        )}

        {!isFinal && benefits && (
          <InfoCard>
            <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "13px", fontWeight: 600, color: "#0f172a" }}>
              {benefitsHeading || "What you get"}
            </Text>
            <Markdown
              markdownCustomStyles={{
                li: { fontSize: "13px", color: "#475569", lineHeight: "20px", margin: "0 0 2px" },
                ul: { margin: 0, paddingLeft: "18px" },
              }}
            >
              {benefits}
            </Markdown>
          </InfoCard>
        )}

        <Section style={{ textAlign: "center", margin: "0 0 14px" }}>
          <Button href={joinUrl}>
            {isNewAccount ? "Set your password" : inviteKind === "existing_account" ? "Accept partnership" : "Confirm details"}
          </Button>
        </Section>

        {expiresAt && (
          <Text className="rsp-caption" style={{ margin: "0 0 12px", fontSize: "12px", color: isFinal ? "#dc2626" : "#64748b", textAlign: "center", fontWeight: isFinal ? 600 : 400 }}>
            Link expires {expiresAt}.
          </Text>
        )}

        <Text className="rsp-caption" style={{ margin: "12px 0 0", fontSize: "12px", color: "#94a3b8" }}>
          Need help? {supportEmail} or {supportPhone}
        </Text>
      </Section>
    </EmailLayout>
  )
}
