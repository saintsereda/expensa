# Expensa Blog Post Pipeline

Pain point → Expensa feature as the pain reliever. Ordered roughly by SEO/search volume potential.

---

## Tier 1 — High search intent, uncontested angle

### 1. "Why I Stopped Giving Finance Apps My Bank Password"
- **Pain point:** Fear of bank login / open banking / Plaid data sharing
- **Feature:** No bank connection required; Apple Pay auto-import via App Intents + iCloud sync
- **Angle:** Explain how Apple Pay automation captures every transaction the moment you tap — no credentials, no OAuth, no third party in between. Privacy-first isn't a compromise, it's the architecture.
- **CTA:** Set up Apple Pay automation in Expensa (link to Shortcuts guide when written)

### 2. "Mint Died. Here's What I Switched To — and Why I'll Never Use a Bank-Sync App Again"
- **Pain point:** Mint shutdown trauma; fear of VC-backed apps going away
- **Feature:** iCloud-native sync (your data lives in your iCloud, not our servers); CSV import from Mint/YNAB so migration is one tap
- **Angle:** Contrast the Mint model (your data on Intuit servers) with Expensa's model (data in your iCloud, indie-owned, can export anytime). Migration walkthrough: export from Mint → import CSV into Expensa with AI column mapping.
- **CTA:** Download Expensa, import your Mint CSV

### 3. "The One iPhone Feature That Makes Budgeting Actually Automatic"
- **Pain point:** Manual entry tedium; "I always forget to log"
- **Feature:** Apple Pay auto-import via App Intents — logs transaction the moment you tap to pay, no app open required
- **Angle:** Step-by-step: how to set up the Shortcuts automation once and never manually log an Apple Pay purchase again. Real-world demo: coffee shop tap → notification: "Logged $4.50 at Blue Bottle → Coffee"
- **CTA:** Set up in 2 minutes (screenshots)

### 4. "YNAB Is Brilliant — But Here's Why It Broke My Brain"
- **Pain point:** YNAB's "give every dollar a job" complexity overwhelms casual users
- **Feature:** Smart Budget Allocation AI — describe your income and priorities, AI splits the budget for you in one tap (GPT-4o, aware of regional spending norms)
- **Angle:** Not anti-YNAB — respect the methodology, but acknowledge the 40-hour learning curve. Show how Expensa's Smart Allocation gets you 80% there in 60 seconds.
- **CTA:** Try Smart Budget Allocation (premium)

### 5. "The Subscription Irony: Paying $12/Month for an App to Tell You You're Broke"
- **Pain point:** Paying for an expense tracker feels absurd
- **Feature:** Free tier that's genuinely useful (Apple Pay import, manual entry, 1 budget, iCloud sync); premium is optional
- **Angle:** Call out competitors who gate basic features behind $8-15/month paywalls. Show what Expensa gives away free vs. what premium adds. Frame premium as "power user tools for when you're ready."
- **CTA:** Download free, upgrade when it makes sense

---

## Tier 2 — Evergreen problem-solving posts

### 6. "Your Budget App Is Lying to You (And It's Not the App's Fault)"
- **Pain point:** Miscategorization — bank sync auto-categorizes poorly; "Amazon" could be groceries, electronics, or pet food
- **Feature:** AI merchant categorization (learns your categories, not generic ones) + Custom Merchant Rules ("always mark Trader Joe's as Groceries")
- **Angle:** Why generic AI categorization fails (one model for millions of users). How Expensa's categorization learns *your* category names and *your* merchants. Once you correct it, it never asks again.
- **CTA:** Enable AI categorization (premium)

### 7. "Set-It-and-Forget-It Budgeting: How to Track Subscriptions Without Thinking About Them"
- **Pain point:** Recurring bills (Netflix, rent, gym) require manual logging every month — so people skip it
- **Feature:** Recurring Transactions — create once, generates automatically on schedule (daily → yearly, custom); notifications day before due
- **Angle:** Show the workflow: create a recurring template for rent, subscriptions, salary. App generates transactions while you sleep. Budget rollover carries settings month to month automatically.
- **CTA:** Set up your first recurring transaction

### 8. "Tracking Shared Expenses Without Losing Your Relationship"
- **Pain point:** Couples / housemates struggle with shared budgets — Splitwise is for splitting, not budgeting together
- **Feature:** Shared Spaces — invite partner via iCloud, real-time sync both ways, shared budget and categories, no account required
- **Angle:** Not a bill-splitter. A shared budget book where both people see the same live picture. Works for couples, roommates, or a small family. No signing up, no sharing a password — just an iCloud share link.
- **CTA:** Share a space with your partner (premium)

### 9. "I Travel for Work — Here's How I Track 6 Currencies Without Losing My Mind"
- **Pain point:** Multi-currency tracking — most apps force a single base currency or break on foreign transactions
- **Feature:** 150+ currencies, live FX rates, stores original + converted amount, built-in currency converter
- **Angle:** Real travel scenario: paid €45 in Berlin, ¥8000 in Tokyo, USD in NYC — all visible in your home currency on one dashboard. Historical rate is locked at transaction time, so your records are accurate forever.
- **CTA:** Add a multi-currency transaction

### 10. "How to Import Your Bank's CSV Export Into Expensa in 3 Minutes"
- **Pain point:** Switching apps or starting fresh — entering past transactions is tedious
- **Feature:** CSV Import with AI column mapping — upload any bank export, AI maps "transaction amount" to "amount" even when column names differ; AI categorizes merchants on import
- **Angle:** Practical how-to with screenshots. Works with bank exports, Mint exports, YNAB exports, custom spreadsheets. Show column mapping review screen.
- **CTA:** Import your transactions

---

## Tier 3 — Behavioral / emotional angle (longer shelf-life)

### 11. "Why You're Avoiding Your Budget App (And How to Fix It)"
- **Pain point:** Psychological shame and avoidance — the app becomes a guilt machine
- **Feature:** Budget overspend alerts via Apple Pay automation (you find out at the moment of the purchase, not weeks later at review time); category budget progress on dashboard
- **Angle:** Avoidance happens when the app is a ledger of past failures. Expensa is designed to inform in real-time so you can course-correct the same day — not sit with shame at month end.
- **CTA:** Enable budget alerts

### 12. "Your Spending Has Patterns. Here's How to Find Them."
- **Pain point:** Overspending without awareness — money leaks you can't see
- **Feature:** Advanced Analytics (spending trends over time, category breakdowns, calendar heatmap, tag analytics)
- **Angle:** The calendar heatmap shows the "Friday effect" or the "grocery run every Wednesday" without you having to think about it. Show real screenshots of the analytics views.
- **CTA:** Unlock analytics (premium)

### 13. "I Tracked Every Expense for 90 Days. Here's What I Found."
- **Pain point:** People don't know where their money goes — vague awareness
- **Feature:** Showcases all of the above in a narrative format — Apple Pay automation, categories, dashboard, budget progress
- **Angle:** First-person narrative (Andrew's own story or a fictionalized composite). Concrete discoveries. Feels like a personal finance journaling piece, functions as a product walkthrough.
- **CTA:** Start your own 90-day track

### 14. "Privacy Policy Theater: What Expense Apps Actually Do With Your Data"
- **Pain point:** Data monetization — apps sell financial behavior data to brokers
- **Feature:** No server account, data in iCloud, no telemetry sold, PrivacyInfo.xcprivacy manifest
- **Angle:** Walk through what "bank-connected" apps collect vs. what Expensa collects. Link to privacy policy. Explain what iCloud sync means technically — your data is end-to-end encrypted in your own CloudKit container.
- **CTA:** Read our privacy policy (link) / Try the privacy-first way

---

## Quick-hit / SEO comparison posts (later)

- "Expensa vs YNAB: Which Is Right for You?" — targets YNAB-curious / YNAB-burnout searchers
- "Best Expense Tracker for iPhone in 2026" — owned by big sites but worth writing for long-tail
- "How to Set Up Apple Pay Budgeting on iPhone" — evergreen, captures Shortcuts users

---

## Writing order recommendation

1. Post #3 (Apple Pay automation) — most differentiated, zero competition, demonstrates core hook
2. Post #2 (Mint migration) — captures active intent from people mid-migration
3. Post #1 (bank password) — emotional resonance, shares well, establishes brand voice
4. Post #7 (recurring transactions) — practical, search volume for "track subscriptions iPhone"
5. Post #4 (YNAB brain broke) — targets competitor searchers, controversy drives shares
