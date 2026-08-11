import { Section, Text, Img } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

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
    <EmailLayout preview="Your seller profile now supports social media links and multiple branches.">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#64748b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Profile Update
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "16px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Two new options on your seller profile
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {firstName || fullname},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 14px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Two new options are now available on your Carbon Cube Kenya seller profile:
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          • Add your social media pages — Buyers can now visit your social media accounts directly from your seller profile.
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 14px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          • Add multiple branches/locations — If your business operates from different locations, you can now add them under the same account.
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

        <Text className="rsp-body" style={{ margin: "0 0 14px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
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
