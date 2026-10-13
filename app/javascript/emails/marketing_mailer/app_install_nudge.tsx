import { Section, Text, Row, Column, Img } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"

type AppInstallNudgeProps = {
  firstName: string
  fullname: string
  role: "buyer" | "seller"
  playStoreUrl: string
  appStoreUrl: string
  appPageUrl: string
  reminderNumber?: number
}

export default function AppInstallNudge({
  firstName,
  fullname,
  role,
  playStoreUrl,
  appStoreUrl,
  appPageUrl,
  reminderNumber = 0,
}: AppInstallNudgeProps) {
  const isSeller = role === "seller"

  const benefits = isSeller
    ? [
        "Manage your listings and respond to buyers instantly",
        "Get real-time notifications for new leads and messages",
        "Track your shop analytics on the go",
      ]
    : [
        "Browse thousands of products from verified sellers",
        "Message sellers and get quick responses",
        "Get notified about price drops and new arrivals",
      ]

  const headline = reminderNumber === 0
    ? "Take Carbon Cube Kenya with you"
    : reminderNumber === 1
    ? "Stay connected on the move with the CCK App"
    : "Don't miss out on real-time deals & inquiries"

  const intro = reminderNumber === 0
    ? "You've been using Carbon Cube Kenya on the web — now get the full experience on your phone, free."
    : reminderNumber === 1
    ? "Quick reminder: the CCK mobile app lets you stay updated in real time with instant push notifications, saving you time."
    : "This is our final reminder to try out the CCK mobile app so you never miss urgent buyer or seller interactions."

  const previewText = reminderNumber === 0
    ? `${firstName}, the Carbon Cube Kenya app is waiting for you`
    : reminderNumber === 1
    ? `${firstName}, quick reminder: get the Carbon Cube Kenya app`
    : `${firstName}, final reminder: install Carbon Cube Kenya app`

  return (
    <EmailLayout preview={previewText}>
      <Section className="rsp-section" style={{ padding: "24px 20px 8px" }}>
        {/* Eyebrow */}
        <Text
          className="rsp-eyebrow"
          style={{
            margin: "0 0 6px",
            fontSize: "11px",
            fontWeight: 600,
            color: "#f59e0b",
            textTransform: "uppercase",
            letterSpacing: "0.5px",
          }}
        >
          {reminderNumber > 0 ? `Reminder • Mobile App` : "Mobile App"}
        </Text>

        {/* Headline */}
        <Text
          className="rsp-h1"
          style={{ margin: "0 0 10px", fontSize: "18px", fontWeight: 700, color: "#0f172a", lineHeight: "24px" }}
        >
          {headline}
        </Text>

        {/* Greeting */}
        <Text className="rsp-body" style={{ margin: "0 0 8px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {firstName || fullname},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 16px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          {intro}
        </Text>

        {/* Benefits list */}
        <Section style={{ margin: "0 0 16px" }}>
          {benefits.map((benefit, i) => (
            <Row key={i} style={{ marginBottom: "8px" }}>
              <Column style={{ width: "20px", verticalAlign: "top", paddingTop: "2px" }}>
                <Text style={{ margin: 0, fontSize: "13px", color: "#f59e0b", fontWeight: 700 }}>✓</Text>
              </Column>
              <Column>
                <Text className="rsp-body" style={{ margin: 0, fontSize: "13px", color: "#334155", lineHeight: "19px" }}>
                  {benefit}
                </Text>
              </Column>
            </Row>
          ))}
        </Section>

        {/* Primary CTA */}
        <Section style={{ margin: "0 0 16px" }}>
          <Button href={appPageUrl}>Download the App</Button>
        </Section>

        {/* Store badges row */}
        <Row style={{ marginBottom: "4px" }}>
          <Column style={{ paddingRight: "8px" }}>
            <a href={playStoreUrl} style={{ textDecoration: "none" }}>
              <Img
                src="https://carboncube-ke.com/google-play-badge.png"
                alt="Get it on Google Play"
                width="120"
                height="36"
                style={{ display: "block" }}
              />
            </a>
          </Column>
          <Column>
            <a href={appStoreUrl} style={{ textDecoration: "none" }}>
              <Img
                src="https://carboncube-ke.com/app-store-badge.png"
                alt="Download on the App Store"
                width="120"
                height="36"
                style={{ display: "block" }}
              />
            </a>
          </Column>
        </Row>

        <Text
          className="rsp-caption"
          style={{ margin: "12px 0 0", fontSize: "12px", color: "#94a3b8", lineHeight: "17px" }}
        >
          It&apos;s free — no subscription needed to get started.
        </Text>
      </Section>
    </EmailLayout>
  )
}
