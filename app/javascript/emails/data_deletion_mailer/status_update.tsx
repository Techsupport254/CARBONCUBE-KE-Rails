import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"

type StatusUpdateProps = {
  name: string
  email: string
  status: string
  token: string
  timestamp: string
}

export default function StatusUpdate({
  name,
  status,
  timestamp,
}: StatusUpdateProps) {
  const isCompleted = status.toLowerCase() === "completed"

  return (
    <EmailLayout preview={`Data deletion request - ${status}`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: isCompleted ? "#16a34a" : "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          {isCompleted ? "Completed" : "Update"}
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Deletion request {status}
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {name},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          {isCompleted
            ? "Your account data has been successfully wiped from our system. All personal information associated with your account has been permanently removed."
            : `The status of your data deletion request has been updated to: ${status}.`}
        </Text>

        <Text className="rsp-caption" style={{ margin: "8px 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          Updated on {timestamp}.
        </Text>
      </Section>
    </EmailLayout>
  )
}
