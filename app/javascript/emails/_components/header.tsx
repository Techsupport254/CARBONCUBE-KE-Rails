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
        textAlign: "left",
      }}
    >
      <table role="presentation" cellPadding="0" cellSpacing="0" border={0} align="left" style={{ width: "auto" }}>
        <tr>
          <td align="left" style={{ verticalAlign: "middle", width: "20px" }}>
            <Img
              src="https://carboncube-ke.com/logo.png"
              width="20"
              height="20"
              alt="Carbon Cube Kenya"
              style={{ display: "inline-block", verticalAlign: "middle" }}
            />
          </td>
          <td align="left" style={{ verticalAlign: "middle", paddingLeft: "8px" }}>
            <Text
              style={{
                margin: 0,
                fontSize: "13px",
                fontWeight: 600,
                color: "#1e293b",
                letterSpacing: "-0.1px",
                textAlign: "left",
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
