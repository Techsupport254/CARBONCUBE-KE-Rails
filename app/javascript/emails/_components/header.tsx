import { Img, Section, Text } from "@react-email/components"

type HeaderProps = {
  variant?: "default" | "minimal"
}

export function Header({ variant = "default" }: HeaderProps) {
  return (
    <Section
      className="rsp-section"
      style={{
        padding: "14px 20px",
        borderBottom: variant === "default" ? "1px solid #f1f5f9" : "none",
      }}
    >
      <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
        <tr>
          <td style={{ verticalAlign: "middle" }}>
            <Img
              src="https://carboncube-ke.com/logo.png"
              width="20"
              height="20"
              alt="Carbon Cube Kenya"
              style={{ display: "inline-block", verticalAlign: "middle" }}
            />
          </td>
          <td style={{ verticalAlign: "middle", paddingLeft: "8px" }}>
            <Text
              style={{
                margin: 0,
                fontSize: "13px",
                fontWeight: 600,
                color: "#1e293b",
                letterSpacing: "-0.1px",
              }}
            >
              Carbon Cube Kenya
            </Text>
          </td>
        </tr>
      </table>
    </Section>
  )
}
