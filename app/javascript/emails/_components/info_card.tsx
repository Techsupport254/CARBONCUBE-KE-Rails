import { Section, Text } from "@react-email/components"
import type { ReactNode } from "react"

type InfoCardProps = {
  children: ReactNode
  label?: string
  /** Card border color — pastel tints for alert/tip variants. */
  borderColor?: string
  /** Card background — tinted fills for alert/tip variants. */
  backgroundColor?: string
}

export function InfoCard({
  children,
  label,
  borderColor = "#e2e8f0",
  backgroundColor,
}: InfoCardProps) {
  return (
    <Section
      className="rsp-card"
      style={{
        backgroundColor: backgroundColor || "#f8fafc",
        border: `1px solid ${borderColor}`,
        borderRadius: "10px",
        padding: "14px 16px",
        margin: "12px 0",
      }}
    >
      {label && (
        <Text
          style={{
            margin: "0 0 6px",
            fontSize: "10px",
            fontWeight: 600,
            color: "#94a3b8",
            letterSpacing: "0.5px",
            textTransform: "uppercase",
          }}
        >
          {label}
        </Text>
      )}
      {children}
    </Section>
  )
}
