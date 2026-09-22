import { Img, Section, Text } from "@react-email/components"
import { Markdown } from "@react-email/markdown"
import { EmailLayout } from "../_components/email_layout"
import { Button } from "../_components/button"
import { InfoCard } from "../_components/info_card"
import { MissingItemsList, type MissingItem } from "./missing_items_list"

type ColdOutreachProps = {
  brandName: string
  contactName: string
  category?: string | null
  registered: boolean
  missingItems: MissingItem[]
  ctaUrl: string
  shopUrl?: string | null
  listingUrl: string
}

export default function ColdOutreach({
  brandName,
  contactName,
  category,
  registered,
  missingItems,
  ctaUrl,
  shopUrl,
  listingUrl,
}: ColdOutreachProps) {
  const listedIn = `, listed under **${category}**`

  const greeting = registered
    ? `Hello ${contactName},\n\n**${brandName}** is featured in Brand Kenya, our verified directory of homegrown Kenyan brands${category ? listedIn : ""}. Your seller account is set up — a few details are still missing from your public listing.`
    : `Hello ${contactName},\n\n**${brandName}** is featured in Brand Kenya, our verified directory of homegrown Kenyan brands${category ? listedIn : ""}. Buyers browsing the directory can already find you — claim your free Carbon Cube seller account to take control of your listing and reach them directly.`

  const next = registered
    ? `Your [Brand Kenya listing](${listingUrl}) updates automatically with your logo and details${shopUrl ? ", and buyers reach you through your storefront" : ""}.`
    : `Once you join, your [Brand Kenya listing](${listingUrl}) updates automatically with your logo, catalogue and contact details — and buyers can message you straight from your storefront.`

  return (
    <EmailLayout
      preview={
        registered
          ? `${brandName}: your Brand Kenya listing needs a few details`
          : `${brandName} is listed in Brand Kenya. Claim your free listing`
      }
    >
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
          {registered ? `${brandName} is in Brand Kenya` : `${brandName} is listed in Brand Kenya`}
        </Text>

        <Markdown>{greeting}</Markdown>

        {missingItems.length > 0 && (
          <InfoCard label={registered ? "Complete your listing" : "Your listing is missing"}>
            <MissingItemsList items={missingItems} />
          </InfoCard>
        )}

        <Section style={{ textAlign: "center", margin: "0 0 14px" }}>
          <Button href={ctaUrl}>
            {registered ? "Complete your profile" : "Claim your listing — it's free"}
          </Button>
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
