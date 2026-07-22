import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"

type CallSummaryEmailProps = {
  customerName: string
  agentName: string
  callType: string
  duration: string
  callReason: string
  agentNotes: string
  ratingLink: string
  customerEmail: string
}

export default function CallSummaryEmail({
  customerName,
  agentName,
  callType,
  duration,
  callReason,
  agentNotes,
  ratingLink,
}: CallSummaryEmailProps) {
  return (
    <EmailLayout preview={`Call summary with ${agentName}`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Call Summary
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Your call summary
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {customerName},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Here is a summary of your recent call with our team.
        </Text>

        <InfoCard>
          <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "4px", width: "80px" }}>Agent</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", paddingBottom: "4px" }}>{agentName}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "4px" }}>Type</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", paddingBottom: "4px" }}>{callType}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "4px" }}>Duration</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", paddingBottom: "4px" }}>{duration}</td>
            </tr>
            {callReason && (
              <tr>
                <td style={{ fontSize: "11px", color: "#94a3b8" }}>Reason</td>
                <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b" }}>{callReason}</td>
              </tr>
            )}
          </table>
        </InfoCard>

        {agentNotes && (
          <InfoCard label="Agent notes">
            <Text className="rsp-body" style={{ margin: 0, fontSize: "13px", color: "#334155", lineHeight: "20px", whiteSpace: "pre-wrap" }}>
              {agentNotes}
            </Text>
          </InfoCard>
        )}

        <Section style={{ margin: "14px 0" }}>
          <Button href={ratingLink}>
            Rate the Call
          </Button>
        </Section>
      </Section>
    </EmailLayout>
  )
}
