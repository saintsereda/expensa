# Expensa Website Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a minimal static website at `expensa.andrewsereda.com` with a placeholder landing page, Privacy Policy, and Terms of Use pages.

**Architecture:** Pure HTML/CSS, no dependencies, no JavaScript. Three pages share one stylesheet. GitHub Pages hosts the site from the `main` branch of `saintsereda/expensa`.

**Tech Stack:** HTML5, CSS3, GitHub Pages, Geist font (Google Fonts)

---

## File Structure

```
expensa/
├── CNAME                  # Custom domain config
├── style.css              # Shared styles for all pages
├── index.html             # Placeholder landing page
├── privacy.html           # Privacy Policy
└── terms.html             # Terms of Use
```

---

### Task 1: Init git repo and create GitHub remote

**Files:**
- Working directory: `/Users/andrewsereda/Personal/Pet-projects/expensa`

- [ ] **Step 1: Init git repo**

```bash
cd /Users/andrewsereda/Personal/Pet-projects/expensa
git init
git checkout -b main
```

- [ ] **Step 2: Create GitHub repo**

```bash
gh repo create saintsereda/expensa --public --description "Expensa app website"
git remote add origin https://github.com/saintsereda/expensa.git
```

- [ ] **Step 3: Create .gitignore**

Create `.gitignore`:
```
.DS_Store
```

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore: init repo"
```

---

### Task 2: CNAME and shared stylesheet

**Files:**
- Create: `CNAME`
- Create: `style.css`

- [ ] **Step 1: Create CNAME**

Create `CNAME`:
```
expensa.andrewsereda.com
```

- [ ] **Step 2: Create style.css**

Create `style.css`:
```css
@import url('https://fonts.googleapis.com/css2?family=Geist:wght@400;500&display=swap');

*, *::before, *::after {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

body {
    font-family: 'Geist', -apple-system, BlinkMacSystemFont, sans-serif;
    background-color: #ffffff;
    color: #000000;
    -webkit-font-smoothing: antialiased;
}

a {
    color: #000000;
    text-decoration: none;
}

a:hover {
    text-decoration: underline;
}

/* Header */
.site-header {
    height: 64px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-bottom: 1px solid #f0f0f0;
}

.site-header a {
    font-size: 16px;
    font-weight: 500;
    letter-spacing: -0.01em;
}

/* Main content */
.content {
    max-width: 680px;
    margin: 0 auto;
    padding: 64px 24px 80px;
}

/* Legal pages */
.content h1 {
    font-size: 32px;
    font-weight: 500;
    letter-spacing: -0.02em;
    margin-bottom: 8px;
}

.content .updated {
    font-size: 14px;
    color: #888888;
    margin-bottom: 48px;
}

.content h2 {
    font-size: 18px;
    font-weight: 500;
    margin-top: 40px;
    margin-bottom: 12px;
    letter-spacing: -0.01em;
}

.content p {
    font-size: 16px;
    line-height: 1.65;
    color: #333333;
}

/* Footer */
.site-footer {
    border-top: 1px solid #f0f0f0;
    padding: 24px;
    text-align: center;
    font-size: 14px;
    color: #888888;
    display: flex;
    justify-content: center;
    gap: 24px;
}

.site-footer a {
    color: #888888;
}

.site-footer a:hover {
    color: #000000;
    text-decoration: none;
}
```

- [ ] **Step 3: Commit**

```bash
git add CNAME style.css
git commit -m "chore: add CNAME and shared stylesheet"
```

---

### Task 3: Landing page

**Files:**
- Create: `index.html`

- [ ] **Step 1: Create index.html**

Create `index.html`:
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Expensa</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <header class="site-header">
        <a href="/">Expensa</a>
    </header>

    <main class="content" style="text-align: center; padding-top: 120px;">
        <h1 style="font-size: 48px; font-weight: 500; letter-spacing: -0.03em; margin-bottom: 16px;">
            Expensa
        </h1>
        <p style="font-size: 18px; color: #888888;">
            Coming soon.
        </p>
    </main>

    <footer class="site-footer">
        <a href="/privacy.html">Privacy Policy</a>
        <a href="/terms.html">Terms of Use</a>
    </footer>
</body>
</html>
```

- [ ] **Step 2: Open in browser and verify it renders correctly**

```bash
open /Users/andrewsereda/Personal/Pet-projects/expensa/index.html
```

Expected: White page, "Expensa" header, centered "Expensa" title, "Coming soon." subtitle, footer with Privacy and Terms links.

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: add placeholder landing page"
```

---

### Task 4: Privacy Policy page

**Files:**
- Create: `privacy.html`

- [ ] **Step 1: Create privacy.html**

Create `privacy.html`:
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy – Expensa</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <header class="site-header">
        <a href="/">Expensa</a>
    </header>

    <main class="content">
        <h1>Privacy Policy</h1>
        <p class="updated">Last updated: [Date]</p>

        <h2>Overview</h2>
        <p>
            Your privacy is important to us. This Privacy Policy explains how Expensa collects, uses, and protects your information when you use our app.
        </p>

        <h2>Data We Collect</h2>
        <p>
            [Placeholder: Describe what data the app collects, e.g. expense entries, categories, account information stored locally or in iCloud.]
        </p>

        <h2>How We Use Data</h2>
        <p>
            [Placeholder: Explain how collected data is used, e.g. to provide app functionality, sync across devices, generate reports.]
        </p>

        <h2>Data Storage</h2>
        <p>
            [Placeholder: Describe where data is stored, e.g. on-device Core Data, iCloud CloudKit sync. Clarify if any data is stored on external servers.]
        </p>

        <h2>Third Parties</h2>
        <p>
            [Placeholder: List any third-party services used, e.g. currency exchange rate APIs. State whether any data is shared with third parties.]
        </p>

        <h2>Contact</h2>
        <p>
            If you have any questions about this Privacy Policy, please contact us at <a href="mailto:hello@andrewsereda.com">hello@andrewsereda.com</a>.
        </p>
    </main>

    <footer class="site-footer">
        <a href="/privacy.html">Privacy Policy</a>
        <a href="/terms.html">Terms of Use</a>
    </footer>
</body>
</html>
```

- [ ] **Step 2: Open in browser and verify**

```bash
open /Users/andrewsereda/Personal/Pet-projects/expensa/privacy.html
```

Expected: Header with "Expensa" linking to `/`, h1 "Privacy Policy", all 6 sections visible, footer links.

- [ ] **Step 3: Commit**

```bash
git add privacy.html
git commit -m "feat: add Privacy Policy page"
```

---

### Task 5: Terms of Use page

**Files:**
- Create: `terms.html`

- [ ] **Step 1: Create terms.html**

Create `terms.html`:
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terms of Use – Expensa</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <header class="site-header">
        <a href="/">Expensa</a>
    </header>

    <main class="content">
        <h1>Terms of Use</h1>
        <p class="updated">Last updated: [Date]</p>

        <h2>Acceptance of Terms</h2>
        <p>
            By downloading or using Expensa, you agree to be bound by these Terms of Use. If you do not agree to these terms, please do not use the app.
        </p>

        <h2>Use of the App</h2>
        <p>
            [Placeholder: Describe permitted use of the app. E.g. personal, non-commercial use only. State any prohibited uses.]
        </p>

        <h2>Intellectual Property</h2>
        <p>
            Expensa and all related content, features, and functionality are owned by Andrew Sereda and are protected by applicable intellectual property laws.
        </p>

        <h2>Disclaimer</h2>
        <p>
            Expensa is provided "as is" without warranties of any kind, either express or implied. We do not warrant that the app will be error-free or uninterrupted.
        </p>

        <h2>Limitation of Liability</h2>
        <p>
            To the fullest extent permitted by law, Andrew Sereda shall not be liable for any indirect, incidental, or consequential damages arising from your use of Expensa.
        </p>

        <h2>Changes to Terms</h2>
        <p>
            We may update these Terms of Use from time to time. Continued use of the app after changes constitutes acceptance of the new terms.
        </p>

        <h2>Contact</h2>
        <p>
            If you have any questions about these Terms, please contact us at <a href="mailto:hello@andrewsereda.com">hello@andrewsereda.com</a>.
        </p>
    </main>

    <footer class="site-footer">
        <a href="/privacy.html">Privacy Policy</a>
        <a href="/terms.html">Terms of Use</a>
    </footer>
</body>
</html>
```

- [ ] **Step 2: Open in browser and verify**

```bash
open /Users/andrewsereda/Personal/Pet-projects/expensa/terms.html
```

Expected: Header with "Expensa" linking to `/`, h1 "Terms of Use", all 7 sections visible, footer links.

- [ ] **Step 3: Commit**

```bash
git add terms.html
git commit -m "feat: add Terms of Use page"
```

---

### Task 6: Push to GitHub and enable GitHub Pages

- [ ] **Step 1: Push to GitHub**

```bash
cd /Users/andrewsereda/Personal/Pet-projects/expensa
git push -u origin main
```

- [ ] **Step 2: Enable GitHub Pages**

```bash
gh api repos/saintsereda/expensa/pages \
  --method POST \
  -f source[branch]=main \
  -f source[path]=/
```

Expected output: JSON response with `"url": "https://expensa.andrewsereda.com"` (may take a moment to propagate).

- [ ] **Step 3: Verify Pages is enabled**

```bash
gh api repos/saintsereda/expensa/pages --jq '.status'
```

Expected: `"built"` or `"building"`

- [ ] **Step 4: Add DNS record**

In your DNS provider (wherever `andrewsereda.com` is managed), add:
```
Type:  CNAME
Name:  expensa
Value: saintsereda.github.io
TTL:   Auto
```

- [ ] **Step 5: Verify site is live**

Wait 1-2 minutes for DNS propagation, then:
```bash
curl -I https://expensa.andrewsereda.com
```

Expected: `HTTP/2 200`
