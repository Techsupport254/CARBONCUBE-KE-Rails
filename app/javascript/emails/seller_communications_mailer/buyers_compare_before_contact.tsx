import { Section, Text, Img } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { Icon } from "../_components/icon"
import { Divider } from "../_components/divider"

type BuyersCompareBeforeContactProps = {
  fullname?: string
  firstName?: string
  dashboardUrl?: string
  bannerUrl?: string
}

export default function BuyersCompareBeforeContact({
  fullname = "Seller",
  firstName = "Seller",
  dashboardUrl = "https://carboncube-ke.com/seller/ads?utm_source=seller_communication&utm_medium=email&utm_campaign=buyers_compare_before_contact&utm_content=review_ads_button",
  bannerUrl = "https://res.cloudinary.com/dwrjceslk/image/upload/v1785482749/emails/ghybhzdpzvpw4ekmi3ct.png",
}: BuyersCompareBeforeContactProps) {
  const greetingName = firstName || fullname || "Seller"

  return (
    <EmailLayout preview="Account Update: Listing recommendations for your Carbon Cube Kenya shop">
      <Section className="rsp-section" style={{ padding: "24px 20px" }}>
        <Img
          src={bannerUrl}
          width="100%"
          alt="Carbon Cube Seller Guidance"
          style={{
            display: "block",
            width: "100%",
            borderRadius: "6px",
            marginBottom: "20px",
            border: "0",
          }}
        />

        <Text
          className="rsp-eyebrow"
          style={{
            margin: "0 0 6px",
            fontSize: "11px",
            fontWeight: 700,
            color: "#64748b",
            textTransform: "uppercase",
            letterSpacing: "0.8px",
          }}
        >
          Seller Account Update
        </Text>

        <Text
          className="rsp-h1"
          style={{
            margin: "0 0 14px",
            fontSize: "18px",
            fontWeight: 800,
            color: "#0f172a",
            lineHeight: "24px",
          }}
        >
          Product Listing Optimization Guidelines
        </Text>

        <Text
          className="rsp-body"
          style={{
            margin: "0 0 10px",
            fontSize: "14px",
            fontWeight: 600,
            color: "#1e293b",
            lineHeight: "20px",
          }}
        >
          Hello {greetingName},
        </Text>

        <Text
          className="rsp-body"
          style={{
            margin: "0 0 14px",
            fontSize: "14px",
            color: "#334155",
            lineHeight: "22px",
          }}
        >
          Prospective buyers compare several product listings before choosing which seller to contact. Ensuring your product information is accurate and consistent across your store helps buyers make confident, faster decisions.
        </Text>

        <Section
          style={{
            margin: "16px 0",
            backgroundColor: "#f8fafc",
            border: "1px solid #e2e8f0",
            borderRadius: "8px",
            padding: "16px",
          }}
        >
          <Text
            style={{
              margin: "0 0 12px",
              fontSize: "12px",
              fontWeight: 800,
              color: "#0f172a",
              textTransform: "uppercase",
              letterSpacing: "0.6px",
            }}
          >
            Recommended Listing Checklist:
          </Text>

          <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
            <tbody>
              <tr>
                <td style={{ verticalAlign: "top", width: "22px", paddingTop: "2px" }}>
                  <Icon name="check-circle-2" size={15} color="#2563eb" alt="" />
                </td>
                <td style={{ fontSize: "13px", color: "#334155", lineHeight: "20px", paddingBottom: "10px" }}>
                  <strong style={{ color: "#0f172a" }}>Information Consistency:</strong> Review your product descriptions and specifications to ensure accuracy across all active listings.
                </td>
              </tr>
              <tr>
                <td style={{ verticalAlign: "top", width: "22px", paddingTop: "2px" }}>
                  <Icon name="tag" size={15} color="#2563eb" alt="" />
                </td>
                <td style={{ fontSize: "13px", color: "#334155", lineHeight: "20px", paddingBottom: "10px" }}>
                  <strong style={{ color: "#0f172a" }}>Price Accuracy:</strong> Verify that listed prices match your current selling prices.
                </td>
              </tr>
              <tr>
                <td style={{ verticalAlign: "top", width: "22px", paddingTop: "2px" }}>
                  <Icon name="archive" size={15} color="#2563eb" alt="" />
                </td>
                <td style={{ fontSize: "13px", color: "#334155", lineHeight: "20px" }}>
                  <strong style={{ color: "#0f172a" }}>Inventory Cleanup:</strong> Remove or archive items that are no longer in stock.
                </td>
              </tr>
            </tbody>
          </table>
        </Section>

        <Text
          className="rsp-body"
          style={{
            margin: "14px 0 18px",
            fontSize: "13px",
            color: "#475569",
            lineHeight: "20px",
          }}
        >
          Taking a few minutes to review your catalog ensures your shop remains easy to navigate and highly responsive to buyer inquiries.
        </Text>

        <Section style={{ margin: "20px 0 16px" }}>
          <Button href={dashboardUrl}>Review Your Listings</Button>
        </Section>

        <Divider color="#e2e8f0" />

        <Text style={{ margin: "12px 0 0", fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
          Regards,<br />
          <strong style={{ color: "#0f172a" }}>Carbon Cube Kenya Operations Team</strong>
        </Text>
      </Section>
    </EmailLayout>
  )
}
