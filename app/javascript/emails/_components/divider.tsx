import { Hr } from "@react-email/components"

type DividerProps = {
  color?: string
}

export function Divider({ color = "#f1f5f9" }: DividerProps) {
  return (
    <Hr
      style={{
        margin: "12px 0",
        border: 0,
        borderTop: `1px solid ${color}`,
        width: "100%",
      }}
    />
  )
}
