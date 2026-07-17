# Blog Strategy — AI Assistant Discovery

**Date:** 2026-07-17
**Status:** Draft — pending review

## Goal

Get AI assistants (ChatGPT, Claude, Perplexity, Google AI Overviews) to surface Expensa when someone
asks them for an expense tracker.

The site and blog are the channel. Success = Expensa appears in assistant answers to the target
queries, and referral traffic from assistant domains converts to installs.

## How this actually works

Assistants learn about an app two ways. Only one is a lever.

1. **Training data** — years of latency, no control. Not a strategy.
2. **Live retrieval** — ChatGPT Search, Perplexity, AI Overviews, and Claude with search fetch live
   pages at answer time. **This is the entire lever.** The blog's job is to be the page they fetch.

## The ceiling — accept this before planning around it

**We cannot win "best expense tracker for iPhone."** Assistants build those answers from Reddit
threads and large third-party listicles. Our own site is, by construction, a biased source for
"recommend me an app" questions, and assistants weight it accordingly. No amount of blog quality
changes this.

**We can own queries where Expensa is the only real answer:**

- "expense tracker without bank login"
- "track Apple Pay purchases automatically iPhone"
- "Mint alternative without Plaid"
- "expense tracker that doesn't sell my data"

On these, there is almost nothing else for an assistant to cite. That is the whole opportunity.

**The strategic consequence:** what changes is **topic selection**, not post format. Chase queries
where we are unique; ignore high-volume general ones. `docs/BLOG_POST_STRUCTURE.md` is already built
for extraction (60-word answer block, comparison tables, concrete facts) — that format is exactly
what assistants lift into citations. Keep it. Re-aim it.

## Priority 0 — `llms.txt` publishes a false privacy claim

`llms.txt` is the file assistants read to understand the product. It currently states:

> On-device AI categorization — your data never leaves your phone

**This is false.** `ExpenseTracker/Services/MerchantCategorizationService.swift:113` sends merchant
data to `https://api.openai.com/v1/responses` (endpoint defined in `OpenAIResponseSupport.swift:102`).
Merchant names leave the device. Receipt scanning does the same via `OpenAICheckScanService.swift`;
Apple Vision is only a fallback.

**Why this outranks every other task:** we are asking assistants to discover the app through a file
that makes them repeat a false privacy claim — about a product whose entire pitch is privacy. When
someone checks, the failure is not "we ranked poorly," it is a broken trust claim on our core
positioning, amplified by the assistants we recruited to say it.

The rest of the site is honest — `privacy.html` discloses OpenAI correctly, including that data is
not used for training. This is an isolated error in `llms.txt`, not a pattern.

**Fix:** rewrite the privacy claims in `llms.txt` to match `privacy.html`. The accurate and still
strong differentiator is *no bank connection, no credentials, no data broker, no account* — not
"nothing leaves the device." Do not weaken it into vagueness; state what is true, precisely.

**Also stale:** `llms.txt` lists 2 blog posts out of 7. Assistants use it as a map and miss most of
the content. Regenerate it as part of the deploy, not by hand — a hand-maintained file will drift
again. (Note the root-file allowlist in `deploy.yml`.)

## Content strategy

Backlog: `docs/blog-post-ideas.md` (14 ideas). Format: `docs/BLOG_POST_STRUCTURE.md`. Both stay.

**Re-prioritize the backlog by "are we the only answer?"** — not by search volume. This inverts the
current ordering, which is intuition-ranked by volume potential. High-volume general queries move
down; narrow queries where we are uniquely citable move up.

**Pillar:** Apple Pay automation — the one genuinely uncontested topic.

**Cadence:** 1 post/week, worked from a queue of ready-to-write briefs rather than a calendar. The
friction in weekly publishing is deciding what to write on the day; a brief already waiting removes
that decision.

## Locale scope

**`en` primary, `uk` secondary (no KPI). The other 6 app languages (de, fr, es, it, pl, pt-BR) get
no blog content.** This is a decision, not a gap.

Under the AI-discovery goal the case is, if anything, stronger: covering 6 more locales with current
resourcing (Andrew + AI, no native reviewers) means mass AI translation — the pattern Google has
classified as scaled content abuse since March 2024. A site-level penalty would remove us from the
retrieval index that this entire strategy depends on. We would be trading the channel for volume in
locales where the Apple Pay hook does not even land (Brazil runs on Pix, Spain on Bizum, Italy on
Satispay and cash, Poland on BLIK).

**Reopening condition:** budget for a native reviewer. Not "more time." German is candidate #1 —
privacy as a cultural norm amplifies the core pitch there.

**No `hreflang`** — it links *equivalent* pages, and our locales carry independent content, so no
equivalent pairs exist. Recorded because its absence looks like a missing basic. Do not "fix" it.

## Technical state

Already correct — do not touch:

- **`robots.txt`** — GPTBot, OAI-SearchBot, ChatGPT-User, ClaudeBot, PerplexityBot, Google-Extended
  all allowed. This is the precondition for retrieval and it is done.
- **Schema.org** — `index.html` carries `MobileApplication`, `Organization`, `WebSite`, `Offer`;
  posts carry `BlogPosting`. Correct types, no work needed.

To fix:

1. **`llms.txt`** — false privacy claim + stale post list (Priority 0 above).
2. **Date locale hardcoded** — `blog/src/layouts/PostLayout.astro:29` calls
   `toLocaleDateString('en-US', ...)` regardless of post language; uk posts show English dates.
3. **UI strings hardcoded** — "Get the app" CTA in `PostLayout.astro`, plus `PostNav` and `EndCTA`,
   render English on uk posts.
4. **Blog index mixes locales** — `blog/src/pages/index.astro` lists all posts regardless of `lang`.

Items 2–4 are uk-rendering polish and rank below Priority 0.

Out of scope: locale route prefixes (`/blog/uk/…`). One uk post, no translation pairs — the flat
namespace is adequate.

## Measurement

Harder than classic SEO, and worth being honest about: there is no impressions dashboard for
assistant answers.

- **Referral traffic** — GA4 segment for `chatgpt.com`, `perplexity.ai`, `claude.ai`,
  `copilot.microsoft.com`. This is the only hard, automatic number.
- **Manual citation audit** — monthly, ask each assistant the target queries and log whether Expensa
  appears and what it cites. Tedious, but it is the only direct read on the actual goal.
- **App Store Connect** — installs attributed to web referrer.
- **GSC** — still useful; AI Overviews draw on the same index.

## Non-goals

- Ranking for "best expense tracker" and similar head terms (see The Ceiling).
- Blog content in the other 6 app languages (see Locale scope).
- Third-party placement — Reddit, listicles, Product Hunt. These are what actually move
  "recommend me an app" answers, and the blog cannot substitute for them. Out of scope here because
  the user scoped this to site and blog, but **this is the highest-leverage work not in this spec**
  and deserves its own decision later.

## Open questions

None blocking. Backlog re-prioritization is the first step of the implementation plan; its output
reorders `blog-post-ideas.md` rather than changing this design.
