import { Section, Text, Img } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { Icon } from "../_components/icon"

type NewFeaturesProps = {
  fullname: string
  firstName: string
  profileUrl?: string
  bannerUrl?: string
  supportUrl: string
}

export default function NewFeatures({
  fullname,
  firstName,
  profileUrl = "https://carboncube-ke.com/profile?edit=true&tab=business&utm_source=seller_communication&utm_medium=email&utm_campaign=new_features&utm_content=update_profile_cta",
  bannerUrl = "https://res.cloudinary.com/dwrjceslk/image/upload/c_scale,f_png,q_auto,w_1200/v1/emails/new_features_banner?_a=BACMTiAE",
  supportUrl,
}: NewFeaturesProps) {
  return (
    <EmailLayout preview="New features to help you grow on Carbon Cube Kenya">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          New Features
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          New features available for sellers
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Dear {firstName || fullname},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 14px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          We have introduced two new features to help you grow your business on Carbon Cube Kenya:
        </Text>

        <Img
          src={bannerUrl}
          alt="New seller features: social media links and business branches"
          width="100%"
          style={{
            display: "block",
            width: "100%",
            height: "auto",
            borderRadius: "6px",
            marginBottom: "16px",
            border: "0",
          }}
        />

        <Section style={{ margin: "10px 0" }}>
          <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
            <tr>
              <td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
                <Icon name="check" size={14} color="#f59e0b" />
              </td>
              <td className="rsp-body" style={{ fontSize: "13px", color: "#475569", lineHeight: "20px", paddingBottom: "10px" }}>
                <strong style={{ color: "#0f172a" }}>Add your social media pages</strong> — Buyers can now visit your social media accounts directly from your seller profile.
              </td>
            </tr>
            <tr>
              <td style={{ verticalAlign: "top", width: "24px", paddingTop: "2px" }}>
                <Icon name="check" size={14} color="#f59e0b" />
              </td>
              <td className="rsp-body" style={{ fontSize: "13px", color: "#475569", lineHeight: "20px" }}>
                <strong style={{ color: "#0f172a" }}>Add multiple branches/locations</strong> — If your business operates from different locations, you can now add them under the same account.
              </td>
            </tr>
          </table>
        </Section>

        <Text className="rsp-body" style={{ margin: "14px 0", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Log in to your seller account and update your profile today.
        </Text>

        <Section style={{ margin: "14px 0" }}>
          <Button href={profileUrl}>
            Update Your Profile
          </Button>
        </Section>

        <Text className="rsp-body" style={{ margin: "14px 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          If you need assistance, feel free to <a href={supportUrl} style={{ color: "#f59e0b", textDecoration: "underline" }}>contact us</a>.
        </Text>

        <Text className="rsp-body" style={{ margin: "14px 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Kind Regards,
          <br />
          <strong style={{ color: "#0f172a" }}>Carbon Cube Kenya Team</strong>
        </Text>
      </Section>
    </EmailLayout>
  )
}
