import { Section, Text, Link } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"

type ChangeEntry = {
  field: string
  from: string
  to: string
}

type AccountUpdatedProps = {
  name: string
  role: string
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
  passwordChanged?: boolean
  changes?: Record<string, [unknown, unknown]> | Record<string, unknown>
}

// Human-readable labels for known fields
const FIELD_LABELS: Record<string, string> = {
  email: "Email",
  fullname: "Full Name",
  username: "Username",
  is_lead: "Team Lead",
  is_manager: "Manager",
  manager_email: "Manager Email",
  compensation_type: "Compensation",
  password: "Password",
}

// Convert raw values to display strings
function displayValue(val: unknown): string {
  if (val === null || val === undefined || val === "") return "—"
  if (typeof val === "boolean") return val ? "Yes" : "No"
  return String(val)
}

function normalizeChanges(
  changes?: Record<string, [unknown, unknown]> | Record<string, unknown>
): ChangeEntry[] {
  if (!changes) return []
  return Object.entries(changes).map(([field, value]) => {
    const label = FIELD_LABELS[field] || field
      .replace(/_/g, " ")
      .replace(/\b\w/g, (c) => c.toUpperCase())
    let fromVal: unknown = null
    let toVal: unknown = null
    if (Array.isArray(value)) {
      fromVal = value[0]
      toVal = value[1]
    } else {
      toVal = value
    }
    return {
      field: label,
      from: displayValue(fromVal),
      to: displayValue(toVal),
    }
  })
}

export default function AccountUpdated({
  name,
  role,
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
  passwordChanged,
  changes,
}: AccountUpdatedProps) {
  const roleLabel = role.charAt(0).toUpperCase() + role.slice(1)
  const changeRows = normalizeChanges(changes)

  return (
    <EmailLayout preview={`Your Carbon Cube Kenya ${roleLabel} account was updated`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Account Updated
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Your account details were updated
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {name},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          An administrator{actorName ? ` (${actorName})` : ""} has updated your <strong>{roleLabel}</strong> account on Carbon Cube Kenya.
        </Text>

        {changeRows.length > 0 && (
          <InfoCard label="What changed">
            <table role="presentation" cellPadding="0" cellSpacing="0" border={0} style={{ width: "100%", fontSize: "13px" }}>
              <thead>
                <tr>
                  <td style={{ padding: "4px 6px", borderBottom: "1px solid #e2e8f0", fontSize: "11px", fontWeight: 600, color: "#64748b", textTransform: "uppercase", letterSpacing: "0.3px" }}>Field</td>
                  <td style={{ padding: "4px 6px", borderBottom: "1px solid #e2e8f0", fontSize: "11px", fontWeight: 600, color: "#64748b", textTransform: "uppercase", letterSpacing: "0.3px" }}>From</td>
                  <td style={{ padding: "4px 6px", borderBottom: "1px solid #e2e8f0", fontSize: "11px", fontWeight: 600, color: "#64748b", textTransform: "uppercase", letterSpacing: "0.3px" }}>To</td>
                </tr>
              </thead>
              <tbody>
                {changeRows.map((row, i) => (
                  <tr key={i}>
                    <td style={{ padding: "5px 6px", borderBottom: "1px solid #f1f5f9", fontWeight: 600, color: "#0f172a" }}>{row.field}</td>
                    <td style={{ padding: "5px 6px", borderBottom: "1px solid #f1f5f9", color: "#94a3b8" }}>{row.from}</td>
                    <td style={{ padding: "5px 6px", borderBottom: "1px solid #f1f5f9", color: "#0f172a" }}>{row.to}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </InfoCard>
        )}

        {passwordChanged && (
          <Section style={{ margin: "12px 0", backgroundColor: "#fffbeb", border: "1px solid #fde68a", borderRadius: "6px", padding: "12px" }}>
            <Text style={{ margin: 0, fontSize: "12px", color: "#92400e", lineHeight: "17px" }}>
              <strong>Heads up:</strong> Your password was changed. If this wasn't expected, please contact our support team immediately at {supportEmail} or {supportPhone}.
            </Text>
          </Section>
        )}

        <InfoCard label="Current Account Details">
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
          {typeof isLead === "boolean" && (
            <Text style={{ margin: "0 0 3px", fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
              <strong>Team lead:</strong> {isLead ? "Yes" : "No"}
            </Text>
          )}
          {typeof isManager === "boolean" && (
            <Text style={{ margin: "0 0 3px", fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
              <strong>Manager:</strong> {isManager ? "Yes" : "No"}
            </Text>
          )}
          {compensationType && (
            <Text style={{ margin: "0 0 3px", fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
              <strong>Compensation:</strong> {compensationType.charAt(0).toUpperCase() + compensationType.slice(1)}
            </Text>
          )}
          <Text style={{ margin: "0", fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
            <strong>Updated:</strong> {timestamp}
          </Text>
        </InfoCard>

        <Section style={{ margin: "14px 0" }}>
          <Button href={dashboardUrl}>Go to Dashboard</Button>
        </Section>

        <Text className="rsp-caption" style={{ margin: "10px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          If you didn't expect this change, please contact us at{" "}
          <Link href={`mailto:${supportEmail}`} style={{ color: "#f59e0b", textDecoration: "none", fontWeight: 500 }}>
            {supportEmail}
          </Link>{" "}
          or call {supportPhone}.
        </Text>
      </Section>
    </EmailLayout>
  )
}
