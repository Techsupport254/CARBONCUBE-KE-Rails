import { Section, Text } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { Icon } from "../_components/icon"

type AccurateListingsProps = {
  fullname: string
  firstName: string
  dashboardUrl: string
}

export default function AccurateListings({ fullname, firstName, dashboardUrl }: AccurateListingsProps) {
  return (
    <EmailLayout preview="Build trust through accurate listings">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Seller Guide
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Build trust through accurate listings
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {firstName || fullname},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Trust begins with honest product information. To help buyers make informed decisions:
        </Text>

        <Section style={{ margin: "10px 0", paddingLeft: "0" }}>
          <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
            <tr>
              <td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
                <Icon name="check" size={14} color="#f59e0b" />
              </td>
              <td className="rsp-body" style={{ fontSize: "13px", color: "#475569", lineHeight: "20px", paddingBottom: "6px" }}>
                Use genuine product photos
              </td>
            </tr>
            <tr>
              <td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
                <Icon name="check" size={14} color="#f59e0b" />
              </td>
              <td className="rsp-body" style={{ fontSize: "13px", color: "#475569", lineHeight: "20px", paddingBottom: "6px" }}>
                Provide accurate descriptions
              </td>
            </tr>
            <tr>
              <td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
                <Icon name="check" size={14} color="#f59e0b" />
              </td>
              <td className="rsp-body" style={{ fontSize: "13px", color: "#475569", lineHeight: "20px", paddingBottom: "6px" }}>
                Display correct pricing
              </td>
            </tr>
            <tr>
              <td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
                <Icon name="check" size={14} color="#f59e0b" />
              </td>
              <td className="rsp-body" style={{ fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
                Update listings whenever details change
              </td>
            </tr>
          </table>
        </Section>

        <Text className="rsp-body" style={{ margin: "10px 0", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Clear and accurate listings help build confidence in your business and create a better marketplace experience for everyone.
        </Text>

        <Section style={{ margin: "14px 0" }}>
          <Button href={dashboardUrl}>
            Review Your Listings
          </Button>
        </Section>
      </Section>
    </EmailLayout>
  )
}
