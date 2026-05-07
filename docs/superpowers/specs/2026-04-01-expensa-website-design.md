# Expensa Website Design

**Date:** 2026-04-01  
**Status:** Approved

## Overview

A minimal static website for the Expensa iOS app, hosted on GitHub Pages at `expensa.andrewsereda.com`. Built with pure HTML/CSS, no dependencies. Apple-style minimalism, Geist font, black/white.

## Scope

Three pages only:
- `index.html` — minimal placeholder landing page
- `privacy.html` — Privacy Policy
- `terms.html` — Terms of Use

## Repository

- **Repo:** `saintsereda/expensa` (new, public)
- **Hosting:** GitHub Pages on `main` branch
- **Custom domain:** `expensa.andrewsereda.com` via `CNAME` file
- **DNS:** User adds CNAME record `expensa` → `saintsereda.github.io` at their DNS provider

## File Structure

```
expensa/
├── CNAME
├── style.css
├── index.html
├── privacy.html
└── terms.html
```

## Styling (`style.css`)

- Font: Geist (Google Fonts or system fallback)
- Colors: #000000 text, #ffffff background
- Simple shared layout: centered content, max-width ~680px
- Header: "Expensa" text logo linking to index
- Footer: links to Privacy and Terms

## Pages

### `index.html`
Minimal placeholder. Contains:
- App name "Expensa"
- Short placeholder tagline
- Links to privacy and terms in footer

### `privacy.html`
Privacy Policy with sections:
1. Overview
2. Data We Collect
3. How We Use Data
4. Data Storage
5. Third Parties
6. Contact

All sections have placeholder text. Includes "Last updated: [date]" placeholder.

### `terms.html`
Terms of Use with sections:
1. Acceptance of Terms
2. Use of the App
3. Intellectual Property
4. Disclaimer
5. Limitation of Liability
6. Changes to Terms
7. Contact

All sections have placeholder text. Includes "Last updated: [date]" placeholder.

## Out of Scope

- App Store screenshots
- Feature sections
- Any JavaScript
- CMS or templating
