import { Section, Text, Link } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"

type AccountCreatedProps = {
  name: string
  role: string
  loginUrl: string
  dashboardUrl: string
  supportEmail: string
  supportPhone: string
  timestamp: string
  email?: string
  username?: string | null
  isLead?: boolean | null
  isManager?: boolean | null
  compensationType?: string | null
  actorName?: string | null
}

export default function AccountCreated({
  name,
  role,
  loginUrl,
  dashboardUrl,
  supportEmail,
  supportPhone,
  timestamp,
  email,
  username,
  isLead,
  isManager,
  compensationType,
  actorName,
}: AccountCreatedProps) {
  const roleLabel = role.charAt(0).toUpperCase() + role.slice(1)

  return (
    <EmailLayout preview={`Your Carbon Cube Kenya ${roleLabel} account is ready`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Account Created
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Your {roleLabel} account is ready
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {name},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          An administrator{actorName ? ` (${actorName})` : ""} has created a <strong>{roleLabel}</strong> account for you on Carbon Cube Kenya.
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          To get started, set your password by using the <strong>"Forgot Password"</strong> link on the login page. A verification code will be sent to your email so you can choose your own password.
        </Text>

        <InfoCard label="Account Details">
          {email && (
            <Text style={{ margin: "0 0 3px", fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
              <strong>Email:</strong> {email}
            </Text>
          )}
          <Text style={{ margin: "0 0 3px", fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
            <strong>Account type:</strong> {roleLabel}
          </Text>
          {username && (
            <Text style={{ margin: "0 0 3px", fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
              <strong>Username:</strong> {username}
            </Text>
          )}
          {isLead && (
            <Text style={{ margin: "0 0 3px", fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
              <strong>Team lead:</strong> Yes
            </Text>
          )}
          {isManager && (
            <Text style={{ margin: "0 0 3px", fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
              <strong>Manager:</strong> Yes
            </Text>
          )}
          {compensationType && (
            <Text style={{ margin: "0 0 3px", fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
              <strong>Compensation:</strong> {compensationType.charAt(0).toUpperCase() + compensationType.slice(1)}
            </Text>
          )}
          <Text style={{ margin: "0", fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
            <strong>Created:</strong> {timestamp}
          </Text>
        </InfoCard>

        <Section style={{ margin: "14px 0", backgroundColor: "#fffbeb", border: "1px solid #fde68a", borderRadius: "6px", padding: "12px" }}>
          <Text style={{ margin: 0, fontSize: "12px", color: "#92400e", lineHeight: "17px" }}>
            <strong>Security tip:</strong> Never share your password with anyone — Carbon Cube staff will never ask for it.
          </Text>
        </Section>

        <Section style={{ margin: "14px 0" }}>
          <Button href={dashboardUrl}>Go to Dashboard</Button>
          {" "}
          <Button href={loginUrl} variant="secondary">Sign In</Button>
        </Section>

        <Text className="rsp-caption" style={{ margin: "10px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          Need help? Contact us at{" "}
          <Link href={`mailto:${supportEmail}`} style={{ color: "#f59e0b", textDecoration: "none", fontWeight: 500 }}>
            {supportEmail}
          </Link>{" "}
          or call {supportPhone}.
        </Text>
      </Section>
    </EmailLayout>
  )
}
