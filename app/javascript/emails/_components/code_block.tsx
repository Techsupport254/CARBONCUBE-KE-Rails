import { Section, Text } from "@react-email/components"

type CodeBlockProps = {
  code: string
  label?: string
}

export function CodeBlock({ code, label = "Your verification code" }: CodeBlockProps) {
  const chars = code.split("")

  return (
    <Section
      style={{
        margin: "14px 0",
        textAlign: "center",
      }}
    >
      <Text
        style={{
          margin: "0 0 6px",
          fontSize: "11px",
          color: "#94a3b8",
          fontWeight: 500,
        }}
      >
        {label}
      </Text>
      <table role="presentation" cellPadding="0" cellSpacing="5" border={0} align="center" style={{ margin: "0 auto" }}>
        <tr>
          {chars.map((char, i) => (
            <td
              key={i}
              className="rsp-code"
              style={{
                width: "32px",
                height: "40px",
                backgroundColor: "#f8fafc",
                border: "1px solid #e2e8f0",
                borderRadius: "5px",
                textAlign: "center",
                verticalAlign: "middle",
                fontFamily: "Outfit, Helvetica, Arial, sans-serif",
                fontSize: "17px",
                fontWeight: 700,
                color: "#1e293b",
              }}
            >
              {char}
            </td>
          ))}
        </tr>
      </table>
    </Section>
  )
}
