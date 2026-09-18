import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { InfoCard } from "../_components/info_card"

type JoinedInternalProps = {
  roleLabel: string
  inviteeName: string
  partnerName?: string | null
  sellerName?: string | null
  acceptedAt?: string | null
  invitedBy?: string | null
  supportEmail: string
}

export default function JoinedInternal({
  roleLabel,
  inviteeName,
  partnerName,
  sellerName,
  acceptedAt,
  invitedBy,
}: JoinedInternalProps) {
  const role = roleLabel.charAt(0).toUpperCase() + roleLabel.slice(1)

  return (
    <EmailLayout preview={`${inviteeName} joined as ${roleLabel}`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#16a34a", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Partner Joined
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          {inviteeName} joined as {role}
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 14px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          A partner invitation has been accepted — access is now live.
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
          {sellerName && (
            <Text className="rsp-body" style={{ margin: "0 0 4px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
              <strong style={{ color: "#0f172a" }}>Seller account:</strong> {sellerName}
            </Text>
          )}
          {acceptedAt && (
            <Text className="rsp-body" style={{ margin: "0 0 4px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
              <strong style={{ color: "#0f172a" }}>Accepted:</strong> {acceptedAt}
            </Text>
          )}
          {invitedBy && (
            <Text className="rsp-body" style={{ margin: 0, fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
              <strong style={{ color: "#0f172a" }}>Invited by:</strong> {invitedBy}
            </Text>
          )}
        </InfoCard>
      </Section>
    </EmailLayout>
  )
}
