import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type BlackFridayEmailProps = {
  fullname: string
  firstName: string
  dashboardUrl: string
}

export default function BlackFridayEmail({ fullname, firstName, dashboardUrl }: BlackFridayEmailProps) {
  return (
    <EmailLayout preview="Black Friday is coming - prepare your shop">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Black Friday
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Black Friday is approaching
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {firstName || fullname},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Black Friday is one of the biggest shopping events of the year. Prepare your shop by updating your listings, checking your inventory, and making sure your product photos are clear and appealing.
        </Text>

        <Section style={{ margin: "14px 0" }}>
          <Button href={dashboardUrl}>
            Prepare Your Shop
          </Button>
        </Section>
      </Section>
    </EmailLayout>
  )
}
