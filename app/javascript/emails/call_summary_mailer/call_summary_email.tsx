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

const FEEDBACK_QUESTIONS = [
  "Rate your overall experience (1–5 stars)",
  "Was your issue fully resolved?",
  "Would you recommend Carbon Cube Kenya to another business?",
  "Any challenges posting ads or responding to customers?",
  "Any other comments or suggestions",
]

export default function CallSummaryEmail({
  customerName,
  agentName,
  callType,
  duration,
  callReason,
  agentNotes,
  ratingLink,
}: CallSummaryEmailProps) {
  const firstName = customerName?.split(" ")[0] || "there"

  return (
    <EmailLayout preview={`Your call summary with ${agentName} — Carbon Cube Kenya`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>

        {/* Eyebrow */}
        <Text
          className="rsp-eyebrow"
          style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}
        >
          Call Summary
        </Text>

        {/* Heading */}
        <Text
          className="rsp-h1"
          style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}
        >
          Your call has been logged ✅
        </Text>

        {/* Greeting */}
        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {firstName},
        </Text>
        <Text className="rsp-body" style={{ margin: "0 0 14px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Thank you for speaking with our support team. Here's a recap of your conversation.
        </Text>

        {/* Call Details */}
        <InfoCard label="Call Details">
          <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "8px", width: "90px", verticalAlign: "top" }}>Agent</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", paddingBottom: "8px" }}>{agentName}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "8px", textTransform: "uppercase" }}>Type</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", paddingBottom: "8px", textTransform: "capitalize" }}>{callType}</td>
            </tr>
            <tr>
              <td style={{ fontSize: "11px", color: "#94a3b8", paddingBottom: "8px" }}>Duration</td>
              <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b", paddingBottom: "8px" }}>{duration}</td>
            </tr>
            {callReason && (
              <tr>
                <td style={{ fontSize: "11px", color: "#94a3b8" }}>Reason</td>
                <td style={{ fontSize: "13px", fontWeight: 600, color: "#1e293b" }}>{callReason}</td>
              </tr>
            )}
          </table>
        </InfoCard>

        {/* Agent Notes */}
        {agentNotes && agentNotes !== "No notes provided" && (
          <InfoCard label="Discussion notes">
            <Text
              className="rsp-body"
              style={{ margin: 0, fontSize: "13px", color: "#334155", lineHeight: "20px", whiteSpace: "pre-wrap" }}
            >
              {agentNotes}
            </Text>
          </InfoCard>
        )}

        {/* Feedback CTA */}
        <Text
          className="rsp-h2"
          style={{ margin: "16px 0 4px", fontSize: "15px", fontWeight: 700, color: "#0f172a" }}
        >
          ⭐ Share your feedback
        </Text>
        <Text className="rsp-body" style={{ margin: "0 0 10px", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
          Your feedback takes less than a minute. We'll ask:
        </Text>

        {/* Questions checklist */}
        <InfoCard backgroundColor="#fffbeb" borderColor="#fde68a">
          {FEEDBACK_QUESTIONS.map((q, i) => (
            <table key={i} role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0} style={{ marginBottom: i < FEEDBACK_QUESTIONS.length - 1 ? "6px" : 0 }}>
              <tr>
                <td style={{ width: "18px", verticalAlign: "top", paddingTop: "1px" }}>
                  <Text style={{ margin: 0, fontSize: "12px", fontWeight: 700, color: "#d97706" }}>✓</Text>
                </td>
                <td>
                  <Text style={{ margin: 0, fontSize: "12px", color: "#334155", lineHeight: "18px" }}>{q}</Text>
                </td>
              </tr>
            </table>
          ))}
        </InfoCard>

        {/* CTA Button */}
        <Section style={{ margin: "16px 0 4px" }}>
          <Button href={ratingLink}>
            Share My Feedback →
          </Button>
        </Section>

        <Text
          className="rsp-caption"
          style={{ margin: "8px 0 0", fontSize: "11px", color: "#94a3b8", lineHeight: "16px" }}
        >
          This link is unique to your call and expires after submission.
          If you did not receive this call, please ignore this email.
        </Text>

      </Section>
    </EmailLayout>
  )
}
