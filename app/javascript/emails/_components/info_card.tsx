import { Section, Text } from "@react-email/components"
import type { ReactNode } from "react"

type InfoCardProps = {
  children: ReactNode
  label?: string
  backgroundColor?: string
  borderColor?: string
}

export function InfoCard({
  children,
  label,
  backgroundColor = "#f8fafc",
  borderColor = "#e2e8f0",
}: InfoCardProps) {
  return (
    <Section
      className="rsp-card"
      style={{
        backgroundColor,
        border: `1px solid ${borderColor}`,
        borderRadius: "5px",
        padding: "12px",
        margin: "10px 0",
      }}
    >
      {label && (
        <Text
          style={{
            margin: "0 0 5px",
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
