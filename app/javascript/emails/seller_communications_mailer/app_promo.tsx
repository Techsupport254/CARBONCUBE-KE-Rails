import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type AppPromoProps = {
  fullname: string
  firstName: string
  appUrl: string
}

export default function AppPromo({ fullname, firstName, appUrl }: AppPromoProps) {
  return (
    <EmailLayout preview="Carbon Cube Kenya is now on mobile">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Mobile App
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Carbon Cube Kenya on mobile
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {firstName || fullname},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Manage your shop, respond to buyers, and track your listings on the go. The Carbon Cube Kenya mobile app brings everything you need right to your phone.
        </Text>

        <Section style={{ margin: "14px 0" }}>
          <Button href={appUrl}>
            Download the App
          </Button>
        </Section>
      </Section>
    </EmailLayout>
  )
}
