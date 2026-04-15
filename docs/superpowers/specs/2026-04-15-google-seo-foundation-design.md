# SEO Foundation Design — expensa.andrewsereda.com

**Date:** 2026-04-15
**Scope:** Google indexing + full enterprise-grade SEO for the landing site (pre-blog)

---

## Goal

Get expensa.andrewsereda.com fully indexed by Google and establish a solid SEO foundation before the app launches on the App Store this week. Covers everything big companies do for a product landing page.

---

## Section 1: Crawlability

### `robots.txt`

New file at the root. Allows all crawlers and points to the sitemap:

```
User-agent: *
Allow: /
Sitemap: https://expensa.andrewsereda.com/sitemap.xml
```

### `sitemap.xml`

New file at the root. Lists all current pages with metadata:

| Page           | Priority | Change Frequency |
|----------------|----------|-----------------|
| `/`            | 1.0      | weekly          |
| `/privacy.html`| 0.3      | monthly         |
| `/terms.html`  | 0.3      | monthly         |

Uses `<lastmod>` set to the current date. Will be extended when the blog launches.

---

## Section 2: Page-level meta tags

Added to `<head>` on every page: `<title>`, `<meta name="description">`, `<link rel="canonical">`, and `<meta name="robots" content="index, follow">`.

### Homepage (`index.html`)
- **Title:** `Expensa — AI-Powered Expense Tracker for iPhone`
- **Description:** `Take control of your finances with Expensa. AI-powered receipt scanning, smart expense categorization, multi-currency support, budget tracking, shared spaces, recurring transactions, and iCloud sync. The smartest personal finance app for iPhone.`
- **Canonical:** `https://expensa.andrewsereda.com/`

### Privacy page (`privacy.html`)
- **Title:** `Privacy Policy — Expensa`
- **Description:** `Read Expensa's privacy policy. Learn how your financial data, receipts, and personal information are collected, stored, and protected in our AI-powered expense tracker.`
- **Canonical:** `https://expensa.andrewsereda.com/privacy.html`

### Terms page (`terms.html`)
- **Title:** `Terms of Use — Expensa`
- **Description:** `Expensa terms of use and conditions. Governs your use of the Expensa AI expense tracking app for iPhone, including budget management, receipt scanning, and shared spaces features.`
- **Canonical:** `https://expensa.andrewsereda.com/terms.html`

Note: Google may rewrite descriptions in SERPs, but uses full text for ranking signals. Long, keyword-rich descriptions are intentional.

---

## Section 3: Social sharing (Open Graph + Twitter Card)

Added to `<head>` on every page. Controls link previews on Twitter/X, iMessage, Slack, LinkedIn, Discord, etc.

### Homepage tags (representative — all pages get equivalents):

```html
<!-- Open Graph -->
<meta property="og:type"         content="website" />
<meta property="og:site_name"    content="Expensa" />
<meta property="og:url"          content="https://expensa.andrewsereda.com/" />
<meta property="og:title"        content="Expensa — AI-Powered Expense Tracker for iPhone" />
<meta property="og:description"  content="AI-powered receipt scanning, smart categorization, multi-currency support, budget tracking, shared spaces, and iCloud sync." />
<meta property="og:image"        content="https://expensa.andrewsereda.com/og-image.png" />
<meta property="og:image:width"  content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:locale"       content="en_US" />

<!-- Twitter/X Card -->
<meta name="twitter:card"        content="summary_large_image" />
<meta name="twitter:title"       content="Expensa — AI-Powered Expense Tracker for iPhone" />
<meta name="twitter:description" content="AI-powered receipt scanning, smart categorization, multi-currency support, budget tracking, shared spaces, and iCloud sync." />
<meta name="twitter:image"       content="https://expensa.andrewsereda.com/og-image.png" />
```

**Placeholder:** `og-image.png` (1200×630px) to be provided by Andrew. Branded dark card with app name + tagline recommended.

---

## Section 4: Structured Data (JSON-LD)

Three schemas embedded in `<script type="application/ld+json">` on the homepage. Privacy and Terms pages get a `WebPage` schema.

### `WebSite` (homepage)
Establishes site as a named entity. Enables Sitelinks Searchbox eligibility.

```json
{
  "@context": "https://schema.org",
  "@type": "WebSite",
  "name": "Expensa",
  "url": "https://expensa.andrewsereda.com"
}
```

### `Organization` (homepage)
Ties brand to web presence. `sameAs` array populated with App Store URL and social profiles once available.

```json
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "Expensa",
  "url": "https://expensa.andrewsereda.com",
  "logo": "https://expensa.andrewsereda.com/og-image.png",
  "sameAs": []
}
```

### `MobileApplication` (homepage)
Tells Google this is an iOS app. Populates app details in search results. `offers.price` is `"0"` if free / freemium.

```json
{
  "@context": "https://schema.org",
  "@type": "MobileApplication",
  "name": "Expensa",
  "operatingSystem": "iOS 17+",
  "applicationCategory": "FinanceApplication",
  "description": "AI-powered expense tracker with receipt scanning, smart categorization, multi-currency support, budget tracking, shared spaces, recurring transactions, and iCloud sync.",
  "offers": {
    "@type": "Offer",
    "price": "0",
    "priceCurrency": "USD"
  }
}
```

### `WebPage` (privacy.html, terms.html)
```json
{
  "@context": "https://schema.org",
  "@type": "WebPage",
  "name": "Privacy Policy — Expensa",
  "url": "https://expensa.andrewsereda.com/privacy.html"
}
```

---

## Section 5: Google Search Console

**Verification tag** (already obtained, to be added to `<head>` of `index.html`):
```html
<meta name="google-site-verification" content="aBkutxuHyxWQc7HJKVw5EnjpIFjfGr1mKf5RJiF3ZXg" />
```

**Post-deployment manual steps (Andrew to do):**
1. Open [Google Search Console](https://search.google.com/search-console)
2. Verify ownership using the meta tag above
3. Submit sitemap: `https://expensa.andrewsereda.com/sitemap.xml`
4. Use "URL Inspection" → "Request Indexing" on the homepage URL

Submitting the sitemap is the single highest-impact step for fast initial indexing.

---

## Files changed

| File            | Action |
|-----------------|--------|
| `robots.txt`    | Create |
| `sitemap.xml`   | Create |
| `index.html`    | Edit — add all meta, OG, Twitter Card, JSON-LD, GSC tag |
| `privacy.html`  | Edit — add title, description, canonical, OG, WebPage schema |
| `terms.html`    | Edit — add title, description, canonical, OG, WebPage schema |
| `og-image.png`  | **Placeholder** — to be provided by Andrew (1200×630px) |

---

## Out of scope (next phase)

- Blog setup (separate design doc)
- Analytics (Google Analytics / Plausible)
- App Store URL in `sameAs` (add once live)
- `og-image.png` creation
