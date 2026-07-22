import { Section, Text, Link } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type AutoReplyProps = {
  name: string
  email: string
  subject: string
  siteUrl: string
  aboutUrl: string
  blogUrl: string
}

export default function AutoReply({ name, subject, siteUrl, aboutUrl, blogUrl }: AutoReplyProps) {
  return (
    <EmailLayout preview="Thank you for contacting Carbon Cube Kenya">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Message Received
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          Thank you for reaching out
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {name},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          We have received your message regarding <strong style={{ color: "#1e293b" }}>"{subject}"</strong> and our team will get back to you as soon as possible.
        </Text>

        <Section style={{ margin: "14px 0" }}>
          <Button href={siteUrl}>
            Visit Website
          </Button>
        </Section>

        <Text className="rsp-body" style={{ margin: "10px 0 4px", fontSize: "14px", fontWeight: 600, color: "#1e293b" }}>
          Explore Carbon Cube Kenya
        </Text>

        <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
          <tr>
            <td style={{ paddingBottom: "4px" }}>
              <Link href={aboutUrl} style={{ fontSize: "13px", color: "#f59e0b", textDecoration: "none" }}>
                About Us
              </Link>
            </td>
          </tr>
          <tr>
            <td>
              <Link href={blogUrl} style={{ fontSize: "13px", color: "#f59e0b", textDecoration: "none" }}>
                Blog
              </Link>
            </td>
          </tr>
        </table>
      </Section>
    </EmailLayout>
  )
}
