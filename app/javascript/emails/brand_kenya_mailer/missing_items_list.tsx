import { Section } from "@react-email/components"
import { Icon } from "../_components/icon"

export type MissingItem = { key: string; label: string }

const itemIcons: Record<string, string> = {
  logo: "image-plus",
  description: "file-text",
  website: "globe",
  social: "share-2",
}

export function MissingItemsList({ items }: { items: MissingItem[] }) {
  return (
    <Section style={{ margin: "4px 0" }}>
      <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
        {items.map((item) => (
          <tr key={item.key}>
            <td style={{ verticalAlign: "top", width: "26px", paddingTop: "3px", fontSize: "0px", lineHeight: "0px" }}>
              <Icon name={itemIcons[item.key] ?? "circle-alert"} size={14} color="#f59e0b" style={{ display: "block" }} />
            </td>
            <td className="rsp-body" style={{ fontSize: "13px", color: "#475569", lineHeight: "20px", paddingBottom: "6px" }}>
              {item.label}
            </td>
          </tr>
        ))}
      </table>
    </Section>
  )
}
