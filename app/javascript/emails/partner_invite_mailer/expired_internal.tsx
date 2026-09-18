import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { InfoCard } from "../_components/info_card"

type ExpiredInternalProps = {
  roleLabel: string
  inviteeName: string
  partnerName?: string | null
  expiresAt?: string | null
  invitedBy?: string | null
  supportEmail: string
}

export default function ExpiredInternal({
  roleLabel,
  inviteeName,
  partnerName,
  expiresAt,
  invitedBy,
}: ExpiredInternalProps) {
  const role = roleLabel.charAt(0).toUpperCase() + roleLabel.slice(1)

  return (
    <EmailLayout preview={`Invite expired — ${inviteeName} never joined`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#dc2626", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Invite Expired
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          {inviteeName} never joined
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 14px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          The {roleLabel} invitation lapsed without acceptance. Automated reminders have stopped — a phone call or a fresh invite from the partners page is the right next step.
        </Text>

        <InfoCard>
          <Text className="rsp-body" style={{ margin: "0 0 4px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
            <strong style={{ color: "#0f172a" }}>Name:</strong> {inviteeName}
          </Text>
          <Text className="rsp-body" style={{ margin: "0 0 4px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
            <strong style={{ color: "#0f172a" }}>Role:</strong> {role}
          </Text>
          {partnerName && roleLabel !== "partner" && (
            <Text className="rsp-body" style={{ margin: "0 0 4px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
              <strong style={{ color: "#0f172a" }}>Partner:</strong> {partnerName}
            </Text>
          )}
          {expiresAt && (
            <Text className="rsp-body" style={{ margin: "0 0 4px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
              <strong style={{ color: "#0f172a" }}>Expired:</strong> {expiresAt}
            </Text>
          )}
          {invitedBy && (
            <Text className="rsp-body" style={{ margin: 0, fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
              <strong style={{ color: "#0f172a" }}>Originally invited by:</strong> {invitedBy}
            </Text>
          )}
        </InfoCard>
      </Section>
    </EmailLayout>
  )
}
