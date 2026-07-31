import { Section, Text, Img } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { Icon } from "../_components/icon"
import { Divider } from "../_components/divider"

type RequestPhoneNumberProps = {
  fullname?: string
  firstName?: string
  updatePhoneUrl?: string
  bannerUrl?: string
}

export default function RequestPhoneNumber({
  fullname = "Seller",
  firstName = "Seller",
  updatePhoneUrl = "https://carboncube-ke.com/seller/update-phone?utm_source=seller_communication&utm_medium=email&utm_campaign=request_phone_number&utm_content=add_phone_cta",
  bannerUrl = "https://res.cloudinary.com/dwrjceslk/image/upload/v1785482749/emails/ghybhzdpzvpw4ekmi3ct.png",
}: RequestPhoneNumberProps) {
  const greetingName = firstName || fullname || "Seller"

  return (
    <EmailLayout preview="Action Required: Add your phone number to receive direct buyer inquiries">
      <Section className="rsp-section" style={{ padding: "24px 20px" }}>
        <Img
          src={bannerUrl}
          width="100%"
          alt="Carbon Cube Kenya Phone Verification"
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
            color: "#2563eb",
            textTransform: "uppercase",
            letterSpacing: "0.8px",
          }}
        >
          Seller Account Advisory
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
          Add Your Contact Phone Number
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
          We noticed that your Carbon Cube Kenya seller account currently does not have an active phone number attached. When prospective buyers browse and compare product listings, they prefer reaching out directly via phone or WhatsApp.
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
            Why adding your phone number is essential:
          </Text>

          <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
            <tbody>
              <tr>
                <td style={{ verticalAlign: "top", width: "22px", paddingTop: "2px" }}>
                  <Icon name="phone-call" size={15} color="#2563eb" alt="" />
                </td>
                <td style={{ fontSize: "13px", color: "#334155", lineHeight: "20px", paddingBottom: "10px" }}>
                  <strong style={{ color: "#0f172a" }}>Direct Buyer Calls:</strong> Allow interested buyers to call your store directly from listing pages.
                </td>
              </tr>
              <tr>
                <td style={{ verticalAlign: "top", width: "22px", paddingTop: "2px" }}>
                  <Icon name="message-square" size={15} color="#2563eb" alt="" />
                </td>
                <td style={{ fontSize: "13px", color: "#334155", lineHeight: "20px", paddingBottom: "10px" }}>
                  <strong style={{ color: "#0f172a" }}>WhatsApp Inquiries:</strong> Receive instant order requests and item inquiries on your phone.
                </td>
              </tr>
              <tr>
                <td style={{ verticalAlign: "top", width: "22px", paddingTop: "2px" }}>
                  <Icon name="shield-check" size={15} color="#2563eb" alt="" />
                </td>
                <td style={{ fontSize: "13px", color: "#334155", lineHeight: "20px" }}>
                  <strong style={{ color: "#0f172a" }}>Buyer Trust Rating:</strong> Stores with verified phone numbers receive higher engagement and buyer response rates.
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
          Please take less than a minute to add your phone number so buyers can connect with your business without delay.
        </Text>

        <Section style={{ margin: "20px 0 16px" }}>
          <Button href={updatePhoneUrl}>Add Phone Number</Button>
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
