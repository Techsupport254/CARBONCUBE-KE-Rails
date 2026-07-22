import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"

type WeeklySellerCheckpointProps = {
  sellerCount: number
  dateRange: string
}

export default function WeeklySellerCheckpoint({
  sellerCount,
  dateRange,
}: WeeklySellerCheckpointProps) {
  return (
    <EmailLayout preview={`Weekly seller checkpoint: ${sellerCount} new sellers`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Weekly Report
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Weekly seller checkpoint
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          {dateRange}
        </Text>

        <Section
          style={{
            backgroundColor: "#f8fafc",
            border: "1px solid #e2e8f0",
            borderRadius: "5px",
            padding: "14px",
            margin: "10px 0",
            textAlign: "center",
          }}
        >
          <Text style={{ margin: 0, fontSize: "28px", fontWeight: 700, color: "#0f172a" }}>
            {sellerCount}
          </Text>
          <Text style={{ margin: "4px 0 0", fontSize: "12px", color: "#94a3b8" }}>
            new sellers this week
          </Text>
        </Section>

        <Text className="rsp-caption" style={{ margin: "10px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          The full CSV and PDF reports are attached to this email.
        </Text>
      </Section>
    </EmailLayout>
  )
}
