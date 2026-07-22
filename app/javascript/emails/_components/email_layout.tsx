import { Html, Head, Preview, Body, Container, Font, Tailwind } from "@react-email/components"
import type { ReactNode } from "react"
import { Header } from "./header"
import { Footer } from "./footer"

type EmailLayoutProps = {
  children: ReactNode
  preview: string
  headerVariant?: "default" | "minimal"
}

const responsiveStyles = `
  @media only screen and (max-width: 480px) {
    .email-container { width: 100% !important; }
    .rsp-h1 { font-size: 16px !important; line-height: 22px !important; }
    .rsp-h2 { font-size: 15px !important; line-height: 21px !important; }
    .rsp-body { font-size: 13px !important; line-height: 20px !important; }
    .rsp-caption { font-size: 11px !important; line-height: 17px !important; }
    .rsp-eyebrow { font-size: 10px !important; }
    .rsp-footer { font-size: 10px !important; }
    .rsp-footer-sm { font-size: 9px !important; }
    .rsp-code { font-size: 15px !important; width: 28px !important; height: 36px !important; }
    .rsp-card { padding: 10px !important; }
    .rsp-section { padding-left: 16px !important; padding-right: 16px !important; }
  }
`

export function EmailLayout({ children, preview, headerVariant = "default" }: EmailLayoutProps) {
  return (
    <Html lang="en" dir="ltr">
      <Head>
        <Font
          fontFamily="Outfit"
          fallbackFontFamily={["Helvetica", "Arial", "sans-serif"]}
          webFont={{
            url: "https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&display=swap",
            format: "woff2",
          }}
        />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <style dangerouslySetInnerHTML={{ __html: responsiveStyles }} />
      </Head>
      <Preview>{preview}</Preview>
      <Body
        style={{
          margin: 0,
          padding: 0,
          backgroundColor: "#f8fafc",
          fontFamily: "Outfit, Helvetica, Arial, sans-serif",
          WebkitFontSmoothing: "antialiased",
        }}
      >
        <Tailwind>
          <Container
            className="email-container"
            style={{
              maxWidth: "480px",
              margin: "0 auto",
              padding: 0,
              backgroundColor: "#ffffff",
              border: "1px solid #e2e8f0",
              borderRadius: "6px",
              overflow: "hidden",
            }}
          >
            <div style={{ height: "3px", backgroundColor: "#f59e0b", width: "100%" }} />
            <Header variant={headerVariant} />
            {children}
            <Footer />
          </Container>
        </Tailwind>
      </Body>
    </Html>
  )
}
