import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type ListingReminderProps = {
  fullname: string
  firstName: string
  dashboardUrl: string
}

export default function ListingReminder({ fullname, firstName, dashboardUrl }: ListingReminderProps) {
  return (
    <EmailLayout preview="Reminder: Keep your listings up to date">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Listing Reminder
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Keep your listings up to date
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {firstName || fullname},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          This is a quick reminder to review and keep your listings on Carbon Cube Kenya current. Regular updates help ensure your products remain visible and relevant to buyers browsing the platform.
        </Text>

        <Section style={{ margin: "14px 0" }}>
          <Button href={dashboardUrl}>
            Manage Listings
          </Button>
        </Section>

        <Text className="rsp-caption" style={{ margin: "10px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}>
          If you require any assistance, feel free to reach out.
        </Text>
      </Section>
    </EmailLayout>
  )
}
