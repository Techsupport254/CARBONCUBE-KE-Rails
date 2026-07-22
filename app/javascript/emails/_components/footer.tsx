import { Section, Text, Link } from "@react-email/components"
import { Icon } from "./icon"

export function Footer() {
  return (
    <Section
      className="rsp-section"
      style={{
        padding: "14px 20px",
        borderTop: "1px solid #f1f5f9",
        backgroundColor: "#fafbfc",
      }}
    >
      {/* Contact rows */}
      <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
        <tr>
          <td style={{ verticalAlign: "middle" }}>
            <Icon name="mail" size={11} color="#94a3b8" />
          </td>
          <td style={{ verticalAlign: "middle", paddingLeft: "5px" }}>
            <Link
              href="mailto:info@carboncube-ke.com"
              className="rsp-footer"
              style={{
                fontSize: "11px",
                color: "#94a3b8",
                textDecoration: "none",
              }}
            >
              info@carboncube-ke.com
            </Link>
          </td>
        </tr>
      </table>

      <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0} style={{ marginTop: "3px" }}>
        <tr>
          <td style={{ verticalAlign: "middle" }}>
            <Icon name="phone" size={11} color="#94a3b8" />
          </td>
          <td style={{ verticalAlign: "middle", paddingLeft: "5px" }}>
            <Link
              href="tel:+254712990524"
              className="rsp-footer"
              style={{
                fontSize: "11px",
                color: "#94a3b8",
                textDecoration: "none",
              }}
            >
              +254 712 990 524
            </Link>
          </td>
        </tr>
      </table>

      <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0} style={{ marginTop: "3px" }}>
        <tr>
          <td style={{ verticalAlign: "middle" }}>
            <Icon name="map-pin" size={11} color="#94a3b8" />
          </td>
          <td style={{ verticalAlign: "middle", paddingLeft: "5px" }}>
            <Text
              className="rsp-footer"
              style={{
                margin: 0,
                fontSize: "11px",
                color: "#94a3b8",
              }}
            >
              9th Floor, CMS Africa, Kilimani, Nairobi
            </Text>
          </td>
        </tr>
      </table>

      {/* Social icons */}
      <table role="presentation" cellPadding="0" cellSpacing="0" border={0} style={{ marginTop: "8px" }}>
        <tr>
          <td style={{ paddingRight: "10px" }}>
            <Link href="https://www.facebook.com/profile.php?id=61574066312678" style={{ textDecoration: "none" }}>
              <Icon name="facebook" size={12} color="#64748b" />
            </Link>
          </td>
          <td style={{ paddingRight: "10px" }}>
            <Link href="https://www.instagram.com/carboncube_kenya/" style={{ textDecoration: "none" }}>
              <Icon name="instagram" size={12} color="#64748b" />
            </Link>
          </td>
          <td style={{ paddingRight: "10px" }}>
            <Link href="https://www.linkedin.com/company/carbon-cube-kenya/" style={{ textDecoration: "none" }}>
              <Icon name="linkedin" size={12} color="#64748b" />
            </Link>
          </td>
          <td>
            <Link href="https://x.com/carboncube_ke" style={{ textDecoration: "none" }}>
              <Icon name="twitter" size={12} color="#64748b" />
            </Link>
          </td>
        </tr>
      </table>

      <Text
        className="rsp-footer-sm"
        style={{
          margin: "8px 0 0",
          fontSize: "10px",
          color: "#cbd5e1",
          lineHeight: "14px",
        }}
      >
        Carbon Cube Kenya Ltd. &middot; 9th Floor, CMS Africa, Kilimani, Nairobi &middot; P.O. Box 00100
      </Text>

      <Link
        href="https://carboncube-ke.com/unsubscribe"
        className="rsp-footer-sm"
        style={{
          fontSize: "10px",
          color: "#94a3b8",
          textDecoration: "underline",
        }}
      >
        Unsubscribe
      </Link>
    </Section>
  )
}
