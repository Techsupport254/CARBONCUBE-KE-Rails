import { Section, Text, Link } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"

type Seller = {
  id: string
  fullname: string | null
  enterpriseName: string | null
  email: string | null
  phoneNumber: string | null
  profilePicture: string | null
  location: string | null
  city: string | null
  createdAt: string
  assignedBy: string
}

type TeamSummaryItem = {
  fullname: string
  email: string
  count: number
  currentTotal: number
}

type WeeklyOnboardingSummaryProps = {
  recipientName: string
  startDate: string
  endDate: string
  personalSellers: Seller[]
  personalCount: number
  personalCurrentTotal: number
  teamSummary: TeamSummaryItem[]
  allTeamSellers: Seller[]
  teamTotal: number
  teamCurrentTotal: number
  isManagerOrLead: boolean
  dashboardUrl: string
}

function formatDate(dateStr: string) {
  try {
    return new Date(dateStr).toLocaleDateString("en-KE", {
      month: "short",
      day: "numeric",
      year: "numeric",
    })
  } catch {
    return dateStr
  }
}

function formatShortDate(dateStr: string) {
  try {
    return new Date(dateStr).toLocaleDateString("en-KE", {
      weekday: "short",
      month: "short",
      day: "numeric",
    })
  } catch {
    return dateStr
  }
}

function sellerName(s: Seller) {
  return s.enterpriseName || s.fullname || "Unnamed seller"
}

function redactEmail(email: string | null): string {
  if (!email) return "—"
  const [local, domain] = email.split("@")
  if (!local || !domain) return email
  const visible = local.slice(0, 2)
  const hidden = local.length > 2 ? "***" : ""
  return `${visible}${hidden}@${domain}`
}

function Avatar({ src, name }: { src?: string | null; name: string }) {
  const initial = (name?.[0] || "?").toUpperCase()
  return src ? (
    <img
      src={src}
      alt={name}
      width="32"
      height="32"
      style={{ borderRadius: "9999px", objectFit: "cover" }}
    />
  ) : (
    <div
      style={{
        width: 32,
        height: 32,
        borderRadius: "9999px",
        backgroundColor: "#f59e0b",
        color: "#ffffff",
        fontSize: 13,
        fontWeight: 700,
        lineHeight: "32px",
        textAlign: "center",
      }}
    >
      {initial}
    </div>
  )
}

function SellerTable({ sellers }: { sellers: Seller[] }) {
  return (
    <table style={{ width: "100%", borderCollapse: "collapse", border: "1px solid #e2e8f0", borderRadius: "5px" }}>
      <thead>
        <tr style={{ backgroundColor: "#f8fafc" }}>
          <th style={{ padding: "10px 8px", textAlign: "left", fontSize: "11px", fontWeight: 600, color: "#64748b", textTransform: "uppercase" }}>Seller</th>
          <th style={{ padding: "10px 8px", textAlign: "left", fontSize: "11px", fontWeight: 600, color: "#64748b", textTransform: "uppercase" }}>Date</th>
        </tr>
      </thead>
      <tbody>
        {sellers.map((seller, i) => (
          <tr key={seller.id} style={{ backgroundColor: i % 2 === 0 ? "#ffffff" : "#f8fafc" }}>
            <td style={{ padding: "10px 8px", verticalAlign: "middle" }}>
              <div style={{ display: "table" }}>
                <div style={{ display: "table-cell", verticalAlign: "middle", paddingRight: "10px" }}>
                  <Avatar src={seller.profilePicture} name={sellerName(seller)} />
                </div>
                <div style={{ display: "table-cell", verticalAlign: "middle" }}>
                  <div style={{ margin: "0 0 1px", fontSize: "13px", fontWeight: 600, color: "#0f172a", lineHeight: "18px" }}>
                    {sellerName(seller)}
                  </div>
                  <div style={{ margin: 0, fontSize: "12px", color: "#64748b", lineHeight: "16px" }}>
                    {redactEmail(seller.email)}
                  </div>
                </div>
              </div>
            </td>
            <td style={{ padding: "10px 8px", verticalAlign: "middle", fontSize: "12px", color: "#475569", whiteSpace: "nowrap" }}>
              {formatShortDate(seller.createdAt)}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}

export default function WeeklyOnboardingSummary({
  recipientName,
  startDate,
  endDate,
  personalSellers,
  personalCount,
  personalCurrentTotal,
  teamSummary,
  allTeamSellers,
  teamTotal,
  teamCurrentTotal,
  isManagerOrLead,
  dashboardUrl,
}: WeeklyOnboardingSummaryProps) {
  const preview = isManagerOrLead
    ? `Team onboarding summary: ${teamTotal} sellers this week`
    : `Your onboarding summary: ${personalCount} sellers this week`

  return (
    <EmailLayout preview={preview}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Weekly Onboarding Report
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Hello, {recipientName}
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 12px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Your onboarding recap for <strong>{formatDate(startDate)}</strong> through <strong>{formatDate(endDate)}</strong>.
        </Text>

        <InfoCard label="This week at a glance">
          <Text style={{ margin: "0 0 6px", fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
            <strong>{personalCount}</strong> seller{personalCount === 1 ? "" : "s"} onboarded by you
          </Text>
          <Text style={{ margin: 0, fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
            <strong>{personalCurrentTotal}</strong> total sellers onboarded by you to date
          </Text>
          {isManagerOrLead && (
            <>
              <Text style={{ margin: "6px 0 0", fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
                <strong>{teamTotal}</strong> sellers onboarded by the team this week
              </Text>
              <Text style={{ margin: 0, fontSize: "13px", color: "#475569", lineHeight: "19px" }}>
                <strong>{teamCurrentTotal}</strong> total sellers onboarded by the team to date
              </Text>
            </>
          )}
        </InfoCard>

        {personalSellers.length > 0 && (
          <Section style={{ margin: "20px 0 0" }}>
            <Text className="rsp-h2" style={{ margin: "0 0 10px", fontSize: "15px", fontWeight: 700, color: "#0f172a" }}>
              Sellers you onboarded
            </Text>
            <SellerTable sellers={personalSellers} />
          </Section>
        )}

        {isManagerOrLead && teamSummary.length > 0 && (
          <Section style={{ margin: "24px 0 0" }}>
            <Text className="rsp-h2" style={{ margin: "0 0 10px", fontSize: "15px", fontWeight: 700, color: "#0f172a" }}>
              Team leaderboard
            </Text>

            {teamSummary.map((member, index) => (
              <InfoCard key={member.email} backgroundColor="#ffffff" borderColor="#e2e8f0">
                <Section style={{ margin: 0 }}>
                  <Text style={{ margin: "0 0 5px", fontSize: "13px", fontWeight: 600, color: "#0f172a" }}>
                    {index + 1}. {member.fullname}
                  </Text>
                  <Text style={{ margin: 0, fontSize: "12px", color: "#64748b" }}>
                    {member.email}
                  </Text>
                </Section>
                <Section style={{ margin: "8px 0 0" }}>
                  <Text style={{ margin: "0 0 3px", fontSize: "13px", color: "#475569" }}>
                    <strong>{member.count}</strong> this week
                  </Text>
                  <Text style={{ margin: 0, fontSize: "13px", color: "#475569" }}>
                    <strong>{member.currentTotal}</strong> all-time
                  </Text>
                </Section>
              </InfoCard>
            ))}
          </Section>
        )}

        {isManagerOrLead && allTeamSellers.length > 0 && (
          <Section style={{ margin: "24px 0 0" }}>
            <Text className="rsp-h2" style={{ margin: "0 0 10px", fontSize: "15px", fontWeight: 700, color: "#0f172a" }}>
              All team onboardings
            </Text>
            <SellerTable sellers={allTeamSellers} />
          </Section>
        )}

        {personalSellers.length === 0 && !isManagerOrLead && (
          <Text className="rsp-body" style={{ margin: "16px 0 0", fontSize: "14px", color: "#64748b", lineHeight: "21px" }}>
            You did not onboard any sellers this week. Head to the dashboard to find new sign-up opportunities.
          </Text>
        )}

        <Section style={{ margin: "20px 0 0" }}>
          <Button href={dashboardUrl}>Open Sales Dashboard</Button>
        </Section>

        <Text className="rsp-caption" style={{ margin: "16px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          This email is sent every Wednesday at 7:00 AM EAT. It covers the past 7 days of seller onboardings.
          {" "}
          {isManagerOrLead ? "Employed sales team, managers, and leads see the full team view; commission foot soldiers see only their own onboardings." : ""}
        </Text>
      </Section>
    </EmailLayout>
  )
}
