import { Img, Section, Text } from "@react-email/components"
import { Markdown } from "@react-email/markdown"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"
import { MissingItemsList, type MissingItem } from "./missing_items_list"

type CompleteProfileProps = {
  brandName: string
  contactName: string
  category?: string | null
  missingItems: MissingItem[]
  profileUrl: string
  shopUrl?: string | null
  listingUrl: string
}

export default function CompleteProfile({
  brandName,
  contactName,
  category,
  missingItems,
  profileUrl,
  shopUrl,
  listingUrl,
}: CompleteProfileProps) {
  const greeting = `Hello ${contactName},\n\n**${brandName}** is part of Brand Kenya, our verified directory of homegrown Kenyan brands${category ? `, listed under **${category}**` : ""}. To present your business professionally to buyers, please complete your dashboard.`

  const next = `Your [Brand Kenya listing](${listingUrl}) updates automatically with your logo and details${shopUrl ? ", and buyers reach you through your storefront" : ""}.`

  return (
    <EmailLayout preview={`${brandName} is in Brand Kenya. Complete your professional profile`}>
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Section style={{ margin: "0 0 10px" }}>
          <Img
            src="https://carboncube-ke.com/illustrations/brand-kenya-badge.png"
            width="44"
            height="44"
            alt="Brand Kenya"
            style={{ display: "inline-block" }}
          />
        </Section>

        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Brand Kenya · Made in Kenya Edition
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          {brandName} is in Brand Kenya
        </Text>

        <Markdown>{greeting}</Markdown>

        <InfoCard label="Complete your profile">
          <MissingItemsList items={missingItems} />
        </InfoCard>

        <Section style={{ textAlign: "center", margin: "0 0 14px" }}>
          <Button href={profileUrl}>Complete your profile</Button>
        </Section>

        <InfoCard>
          <Text className="rsp-body" style={{ margin: "0 0 4px", fontSize: "13px", fontWeight: 600, color: "#0f172a" }}>
            What happens next
          </Text>
          <Markdown>{next}</Markdown>
        </InfoCard>
      </Section>
    </EmailLayout>
  )
}
