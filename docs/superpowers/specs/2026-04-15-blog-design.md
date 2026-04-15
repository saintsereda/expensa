# Blog Design — expensa.andrewsereda.com/blog/

**Date:** 2026-04-15
**Scope:** Add an Astro-powered blog at `/blog/` alongside the existing landing page

---

## Goal

Drive organic traffic to the Expensa App Store listing through personal finance tips content. Blog lives at `expensa.andrewsereda.com/blog/`. Converts readers via in-post and end-of-post App Store CTAs.

---

## Section 1: Architecture & Deployment

### Repo structure

```
expensa/
├── index.html                        ← existing landing page (untouched)
├── privacy.html                      ← existing
├── terms.html                        ← existing
├── robots.txt                        ← existing
├── sitemap.xml                       ← replaced by Astro-generated sitemap
├── style.css                         ← existing
├── og-image.png                      ← existing placeholder
├── blog/                             ← NEW: Astro project
│   ├── src/
│   │   ├── content/
│   │   │   └── posts/               ← markdown blog posts go here
│   │   ├── layouts/
│   │   │   ├── BaseLayout.astro     ← html shell, dark/light mode, fonts
│   │   │   └── PostLayout.astro     ← wraps BaseLayout, adds post header + CTAs
│   │   ├── pages/
│   │   │   ├── index.astro          ← /blog/ listing page
│   │   │   ├── [slug].astro         ← /blog/[slug]/ individual posts
│   │   │   └── rss.xml.js           ← /blog/rss.xml feed
│   │   └── components/
│   │       ├── AppStoreCTA.astro    ← inline mid-post CTA
│   │       └── EndCTA.astro         ← end-of-post CTA
│   ├── astro.config.mjs
│   └── package.json
└── .github/
    └── workflows/
        └── deploy.yml               ← NEW: builds + deploys everything
```

### Deployment workflow (`.github/workflows/deploy.yml`)

Triggers on every push to `main`:

1. Checkout repo
2. Install Node + deps (`npm ci` in `blog/`)
3. Build Astro (`npm run build` → output to `blog/dist/`)
4. Create deploy folder:
   - Copy root HTML/CSS/media files to deploy root
   - Copy `blog/dist/` contents to `deploy/blog/`
5. Deploy combined folder to GitHub Pages via `actions/deploy-pages`

The landing page is served from the root unchanged. Astro owns only `/blog/*`.

---

## Section 2: URL Structure & Routing

```
expensa.andrewsereda.com/
├── /                       ← existing landing page (unchanged)
├── /blog/                  ← post listing
├── /blog/[slug]/           ← individual posts (clean URLs, no .html)
├── /blog/rss.xml           ← RSS feed
└── /sitemap.xml            ← Astro-generated, covers all pages + posts
```

**Slug format:** kebab-case derived from markdown filename.
`how-to-track-expenses.md` → `/blog/how-to-track-expenses/`

**Listing sort:** newest first. No pagination until 20+ posts exist.

---

## Section 3: Design System

Emil Kowalski-inspired — clean, typographic, minimal. Supports light and dark mode.

### Layout

- Post content: max-width `692px`, centered
- Listing page: max-width `860px`, centered
- Responsive padding: `px-6 py-12` mobile → `md:py-16` desktop

### Typography

- Font: **Inter** via `@fontsource/inter` (self-hosted, no Google Fonts latency)
- Body: `17px`, `line-height: 1.75`
- Post title: `~32px`, `font-weight: 600`
- Section headings: `font-weight: 550`
- Muted text (dates, reading time): smaller, lower opacity

### Colors

| Token        | Light mode          | Dark mode           |
|--------------|---------------------|---------------------|
| Background   | `#ffffff`           | `#0a0a0a`           |
| Text         | `#111111`           | `#ededed`           |
| Muted        | `#666666`           | `#888888`           |
| Accent       | `rgb(120, 115, 255)`| `rgb(120, 115, 255)`|

Accent color matches the landing page violet — consistent brand across the whole domain.

### Dark/light mode

- Toggle button (icon) in top-right of header
- Saves preference to `localStorage`
- Respects `prefers-color-scheme` on first visit
- Implemented via a `data-theme` attribute on `<html>` + CSS custom properties

### Code blocks

Syntax highlighted via Astro's built-in **Shiki**:
- Dark mode: `github-dark` theme
- Light mode: `github-light` theme

---

## Section 4: Blog Listing Page (`/blog/`)

### Header
- Left: "Expensa" → links to `https://expensa.andrewsereda.com/`
- Right: dark/light mode toggle

### Content
- Page title: "Blog"
- Chronological post list (newest first), each entry:
  - Post title (link)
  - Date · reading time (e.g. "Apr 15, 2026 · 5 min read")
  - One-line excerpt
  - Thin divider between entries

### Footer
- Privacy Policy, Terms of Use links (matching landing page footer)

---

## Section 5: Post Page & CTA

### Header
Same as listing page.

### Post header
- Title (`h1`, weight 600, ~32px)
- Date · reading time in muted text
- Thin divider before body

### Body
Full markdown rendering: headings, lists, blockquotes, inline code, fenced code blocks, images.

### Inline CTA (`<AppStoreCTA />`)

Author places this anywhere in markdown. Renders as a subtle card:

```
┌──────────────────────────────────────────────────┐
│  📱  Track your expenses automatically            │
│      Expensa — AI-powered expense tracker         │
│                           [Download for free →]   │
└──────────────────────────────────────────────────┘
```

- Rounded corners, 1px border in accent color (low opacity)
- Background: slight tint of accent color (very low opacity)
- Adapts to light/dark mode
- Links to App Store URL

### End-of-post CTA (`<EndCTA />`)

Automatically appended to every post after the content ends. More prominent:

```
┌──────────────────────────────────────────────────┐
│  Ready to take control of your finances?         │
│  Expensa tracks spending, scans receipts,        │
│  and gives you clarity — automatically.          │
│                                                  │
│       [Download Expensa on the App Store →]      │
└──────────────────────────────────────────────────┘
```

- Slightly larger padding than inline CTA
- Same accent border/background treatment
- Always present — no author action required

### Footer
Same as listing page.

---

## Section 6: RSS Feed, Sitemap & Open Graph

### RSS feed (`/blog/rss.xml`)

Generated by Astro from post frontmatter. Each entry includes:
- Title
- Description/excerpt
- Publication date
- Post URL

### Sitemap (`/sitemap.xml`)

Generated by `@astrojs/sitemap`. Covers:
- `expensa.andrewsereda.com/`
- `expensa.andrewsereda.com/blog/`
- All blog post URLs

Replaces the hand-written `sitemap.xml`. Auto-updates on every deploy.

### Open Graph per post

Post frontmatter drives OG tags automatically:

```md
---
title: "How to Track Expenses Without Thinking About It"
description: "The 3-step system that makes expense tracking effortless."
date: 2026-04-20
---
```

Tags generated:
- `og:title` ← post title
- `og:description` ← post description
- `og:url` ← full canonical post URL
- `og:image` ← falls back to `/og-image.png` (per-post images can be added later)
- `twitter:card`, `twitter:title`, `twitter:description`, `twitter:image`

---

## Post frontmatter schema

```md
---
title: string         # Post title (required)
description: string   # One-line excerpt shown in listing + OG tags (required)
date: YYYY-MM-DD      # Publication date (required)
---
```

---

## Files changed

| Path | Action |
|------|--------|
| `blog/` | Create — full Astro project |
| `blog/src/content/posts/` | Create — markdown posts directory |
| `blog/src/layouts/BaseLayout.astro` | Create |
| `blog/src/layouts/PostLayout.astro` | Create |
| `blog/src/pages/index.astro` | Create — listing page |
| `blog/src/pages/[slug].astro` | Create — post page |
| `blog/src/pages/rss.xml.js` | Create — RSS feed |
| `blog/src/components/AppStoreCTA.astro` | Create — inline CTA |
| `blog/src/components/EndCTA.astro` | Create — end-of-post CTA |
| `blog/astro.config.mjs` | Create |
| `blog/package.json` | Create |
| `.github/workflows/deploy.yml` | Create — build + deploy pipeline |
| `sitemap.xml` | Remove — replaced by Astro-generated version |

---

## Out of scope (future)

- Per-post custom OG images
- Tags / categories
- Pagination (add at 20+ posts)
- Search
- Comments
- Analytics
