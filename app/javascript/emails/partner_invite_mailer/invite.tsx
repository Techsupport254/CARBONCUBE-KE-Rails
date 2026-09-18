import { Section, Text } from "@react-email/components"
import { Markdown } from "@react-email/markdown"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"

type InviteProps = {
  stage: string
  inviteKind: string
  roleLabel: string
  inviteeName: string
  partnerName?: string | null
  joinUrl: string
  expiresAt?: string | null
  invitedBy?: string | null
  benefits?: string | null
  benefitsHeading?: string | null
  supportEmail: string
  supportPhone: string
}

export default function Invite({
  inviteKind,
  roleLabel,
  inviteeName,
  partnerName,
  joinUrl,
  expiresAt,
  invitedBy,
  benefits,
  benefitsHeading,
  supportEmail,
  supportPhone,
}: InviteProps) {
  const role = roleLabel.charAt(0).toUpperCase() + roleLabel.slice(1)
  const isNewAccount = inviteKind === "new_account"
  const isExisting = inviteKind === "existing_account"

  return (
    <EmailLayout preview={`You've been invited to join Carbon Cube Kenya as a ${roleLabel}`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Partnership Invitation
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          {isNewAccount ? `Your ${roleLabel} account is ready` : `You're invited to join as a ${roleLabel}`}
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hello {inviteeName},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 14px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          {partnerName && roleLabel !== "partner" ? (
            <>{partnerName} has partnered with Carbon Cube Kenya, and you've been added as a {roleLabel} on their network. </>
          ) : (
            <>Carbon Cube Kenya has set up a formal {roleLabel} relationship for your business. </>
          )}
          {isNewAccount && "A seller account has been created for you — set your password to activate it and start receiving pricing and business updates."}
          {isExisting && "Accept the invitation to activate the partnership on your existing seller account."}
          {inviteKind === "contact_confirm" && "Confirm your details to stay connected on partnership updates."}
        </Text>

        <Section style={{ textAlign: "center", margin: "0 0 14px" }}>
          <Button href={joinUrl}>
            {isNewAccount ? "Set your password" : isExisting ? "Accept partnership" : "Confirm details"}
          </Button>
        </Section>

        {expiresAt && (
          <Text className="rsp-caption" style={{ margin: "0 0 12px", fontSize: "12px", color: "#64748b", textAlign: "center" }}>
            This link expires on {expiresAt}.
          </Text>
        )}

        {benefits && (
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

        <InfoCard>
          <Text className="rsp-body" style={{ margin: "0 0 4px", fontSize: "13px", fontWeight: 600, color: "#0f172a" }}>
            What happens next
          </Text>
          <Text className="rsp-body" style={{ margin: 0, fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
            {isNewAccount
              ? "Set your password, sign in, and complete your profile — you can then upload products and receive updates."
              : "Once you accept, the partnership is activated and you'll start receiving pricing and important updates."}
          </Text>
        </InfoCard>

        {invitedBy && (
          <Text className="rsp-caption" style={{ margin: "12px 0 0", fontSize: "12px", color: "#94a3b8" }}>
            Invited by {invitedBy} · Questions? {supportEmail} or {supportPhone}
          </Text>
        )}
      </Section>
    </EmailLayout>
  )
}
