import { Link } from "@react-email/components"

type ButtonProps = {
  href: string
  children: React.ReactNode
  variant?: "primary" | "secondary"
}

export function Button({ href, children, variant = "primary" }: ButtonProps) {
  const baseStyle: Record<string, string | number> = {
    display: "inline-block",
    padding: "8px 16px",
    fontSize: "13px",
    fontWeight: 600,
    borderRadius: "5px",
    textDecoration: "none",
  }

  const variantStyles = {
    primary: {
      backgroundColor: "#f59e0b",
      color: "#ffffff",
    },
    secondary: {
      backgroundColor: "#f1f5f9",
      color: "#334155",
      border: "1px solid #e2e8f0",
    },
  }

  return (
    <Link
      href={href}
      style={{
        ...baseStyle,
        ...variantStyles[variant],
      }}
    >
      {children}
    </Link>
  )
}
