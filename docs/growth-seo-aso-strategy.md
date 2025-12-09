# Growth, SEO & ASO Strategy

This document outlines the collaborative strategy for both Development and Marketing teams to maximize organic growth for Web and Mobile.

## 1. Technical SEO (For Developers)

The foundation of SEO is a technically sound application.

### Core Web Vitals
Google uses these metrics as a direct ranking factor.
*   **LCP (Largest Contentful Paint)**: Main content load time. Target industry standard benchmarks.
*   **CLS (Cumulative Layout Shift)**: Visual stability. Target industry standard benchmarks.
*   **INP (Interaction to Next Paint)**: Responsiveness. Target industry standard benchmarks.

### Site Architecture & Crawlability
*   **SSR/SSG**: For React/Next.js/Vue apps, use **Server-Side Rendering** or **Static Site Generation**. Google bots struggle with client-side only rendering.
*   **Sitemap.xml**: Auto-generate sitemaps (e.g., `next-sitemap`). Submit to Google Search Console.
*   **Robots.txt**: Explicitly allow crawling of public pages; disallow API routes and admin panels.
*   **Canonical Tags**: Implement `<link rel="canonical">` to prevent duplicate content penalties (e.g., `www.` vs non-`www`, or tracking params).

### Structured Data (JSON-LD)
*   Implement **Schema.org** markup. Essential for "Rich Snippets" (Stars, FAQ, pricing in search results).
*   **Types**: `Organization`, `Product`, `BreadcrumbList`, `Article`, `FAQPage`.

## 2. Content & Marketing SEO (For Marketing Team)

### Keyword Strategy
*   **Intent Targeting**: Focus on **user intent** (Informational, Navigational, Transactional).
    *   *Bad*: "Software"
    *   *Good*: "Best open source CRM for startups"
*   **Long-Tail Keywords**: Lower volume but higher conversion. easier to rank for.

### Content Quality (E-E-A-T)
Google evaluates: **Experience, Expertise, Authoritativeness, and Trustworthiness**.
*   **Author Bios**: Attribute posts to experts with LinkedIn profiles.
*   **Clusters**: Create "Pillar Pages" (broad topic) linked to "Cluster Content" (specific sub-topic). Internal linking is crucial.

### AI Search Optimization
*   **Zero-Click Searches**: Optimize for Featured Snippets. Answer the query directly in the first paragraph.
*   **Conversational Content**: Write naturally to match voice search and AI queries.

## 3. App Store Optimization (ASO)

For mobile growth, the App Store (iOS) and Play Store (Android) are your search engines.

### Textual Optimization (Keywords)
*   **App Title**: Include the heaviest weighted keyword (e.g., "Carbon - **Marketing Budget Tracker**").
    *   *Limit*: 30 chars (iOS), 30 chars (Android, strict).
*   **Subtitle (iOS) / Short Description (Android)**: Use secondary high-volume keywords. Call to action.
*   **Keyword Field (iOS Only)**: 100 characters. Use single words separated by commas, no spaces. Do not duplicate words from Title.

### Visual Optimization (Conversion Rate)
*   **Icon**: Simple, recognizable, high contrast. Test on different backgrounds.
*   **Screenshots**:
    *   First 3 are critical.
    *   Use captions on top of images to explain features.
    *   Show, don't just tell.
*   **Preview Video**: 15-30 seconds. Focus on the "Aha!" moment immediately.

### Reputation Management
*   **Ratings & Reviews**: High volume of 4.5+ star ratings is a massive ranking factor.
*   **Prompting**: Ask for reviews *after* a positive user action (e.g., "Task completed!"), not at launch.
*   **Reply**: Respond to every review, especially negative ones.

## 4. Tools Stack
*   **SEO Tools**: Ahrefs, SEMrush, Google Search Console, Google Analytics 4 (GA4).
*   **ASO Tools**: AppTweak, Sensor Tower, Mobile Action.
*   **Performance**: Lighthouse, PageSpeed Insights.
