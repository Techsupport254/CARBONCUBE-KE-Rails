import { Section, Text, Link } from "@react-email/components"
import { EmailLayout } from "../_components/email_layout"

type Product = {
  title: string
  sellerName: string
  imageUrl: string
  reviewUrl: string
}

type ProductReviewRequestProps = {
  name: string
  products: Product[]
}

export default function ProductReviewRequest({ name, products }: ProductReviewRequestProps) {
  return (
    <EmailLayout preview="How was your experience?">
      <Section className="rsp-section" style={{ padding: "20px" }}>
        <Text className="rsp-eyebrow" style={{ margin: "0 0 6px", fontSize: "11px", fontWeight: 600, color: "#f59e0b", textTransform: "uppercase", letterSpacing: "0.5px" }}>
          Review Request
        </Text>

        <Text className="rsp-h1" style={{ margin: "0 0 8px", fontSize: "17px", fontWeight: 700, color: "#0f172a", lineHeight: "22px" }}>
          How was your experience?
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 6px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Hi {name},
        </Text>

        <Text className="rsp-body" style={{ margin: "0 0 10px", fontSize: "14px", color: "#475569", lineHeight: "21px" }}>
          Your feedback helps other buyers make informed decisions. Take a moment to review the products you recently interacted with.
        </Text>

        {products.map((product, i) => (
          <Section
            key={i}
            style={{
              border: "1px solid #e2e8f0",
              borderRadius: "5px",
              padding: "10px",
              marginBottom: "10px",
            }}
          >
            <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" border={0}>
              <tr>
                <td style={{ width: "44px", verticalAlign: "top" }}>
                  <img
                    src={product.imageUrl}
                    width="44"
                    height="44"
                    alt={product.title}
                    style={{ borderRadius: "4px", objectFit: "contain", display: "block", background: "#f8fafc" }}
                  />
                </td>
                <td style={{ verticalAlign: "top", paddingLeft: "10px" }}>
                  <Text style={{ margin: "0 0 2px", fontSize: "13px", fontWeight: 600, color: "#1e293b" }}>
                    {product.title}
                  </Text>
                  <Text style={{ margin: "0 0 4px", fontSize: "11px", color: "#94a3b8" }}>
                    {product.sellerName}
                  </Text>
                  <Link
                    href={product.reviewUrl}
                    style={{
                      display: "inline-block",
                      fontSize: "13px",
                      fontWeight: 500,
                      color: "#f59e0b",
                      textDecoration: "none",
                    }}
                  >
                    Write a review
                  </Link>
                </td>
              </tr>
            </table>
          </Section>
        ))}
      </Section>
    </EmailLayout>
  )
}
