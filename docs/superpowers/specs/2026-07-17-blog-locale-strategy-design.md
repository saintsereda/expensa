# Blog Locale Strategy — Design

**Date:** 2026-07-17
**Status:** Draft — pending review
**Supersedes:** nothing (first locale-strategy spec)

## Problem

Expensa the iOS app ships in 8 languages (en, uk, de, fr, es, it, pl, pt-BR). The blog does not. The
open question was whether the blog should follow the app to all 8 locales.

It should not. This spec records that decision, its reasoning, and what we do instead.

## Goal

Organic search → App Store installs from the **English-speaking market** (US/UK/CA/AU).

Ukrainian is a secondary track: it is published because it costs nothing extra (Andrew writes it
natively) and serves existing Ukrainian users. **It is explicitly not in the KPI.** Do not measure
the strategy by uk numbers, and do not let uk work displace en work.

## Non-goals

**The remaining 6 app languages (de, fr, es, it, pl, pt-BR) get no blog content.** This is a
decision, not a gap in the plan.

Three reasons, in order of weight:

1. **Scaled content abuse risk.** The only way to cover 6 more locales with the current resourcing
   (Andrew + AI, no native speakers) is mass AI translation of one post set. That is the pattern
   Google has classified as scaled content abuse since March 2024. The downside is not "the new
   pages rank poorly" — it is a site-level penalty that would take down the English content that
   already works. Asymmetric bet against the actual goal.
2. **Trust in a finance context.** Non-native phrasing in copy about handing an app your financial
   data costs conversion far more than in other niches. Without a native reviewer, we cannot detect
   the problem, let alone fix it.
3. **Maintenance debt.** 8 locales × N posts means every feature change rots in 8 places.

**Reopening condition: budget for a native speaker in the target locale.** Not "more free time" —
specifically a native reviewer. Without one, do not reopen this question.

If/when it reopens, **German is candidate #1** — not for market size, but because it is the one
locale where the local reality amplifies the core pitch rather than fighting it (privacy as a
cultural norm, DSGVO literacy, growing Apple Pay adoption). Other locales were considered and are
weaker fits because their payment rails sideline the Apple Pay hook: Brazil runs on Pix, Spain on
Bizum, Italy on Satispay and cash, Poland on BLIK. Ukraine is a poor commercial target despite being
free to write: monobank and Privat24 already auto-categorize for free, and ARPU is low.

## Locale model

Two blog locales: `en` (primary), `uk` (secondary).

Content is **independent per locale, not translated.** Ukrainian posts are original pieces for the
Ukrainian context; they are not mirrors of English posts.

### No hreflang — deliberate

`hreflang` links *equivalent* pages across locales. Our locales carry independent content, so
equivalent pairs do not exist. Adding `hreflang` here would be incorrect.

This is recorded because its absence looks like a missing i18n basic. **Do not "fix" it.** If the
content model ever changes to true per-locale translations of the same posts, revisit.

## Content plan (en)

The backlog in `docs/blog-post-ideas.md` (14 ideas, Tier 1–3) is sound and stays as-is. Post
structure follows `docs/BLOG_POST_STRUCTURE.md`. Neither needs rewriting.

**The one real gap: priority is set by intuition, not data.** The backlog orders itself "roughly by
SEO/search volume potential" with no keyword research behind it. At one post per week, a
misprioritized slot costs a week of work on a query nobody searches.

**Fix:** before writing, validate the top 5 backlog items against real search demand (volume,
competition, SERP shape). Re-order on the evidence. Record the data next to each idea so the order
is auditable later.

**Cluster:** build around Apple Pay automation as the pillar — the one topic with a genuinely
uncontested angle. Deep-dives cross-link to it and to each other per the cross-linking rule in
`BLOG_POST_STRUCTURE.md`.

**Cadence:** 1 post/week.

**Working format: a queue of ready-to-write briefs, not a calendar.** The friction in weekly
publishing is deciding what to write on the day. A brief already waiting removes that decision. A
missed week is then a missed week, not a derailed plan.

## Ukrainian track

Ships when Andrew feels like writing it. No cadence commitment, no KPI.

One post exists: `porivnyannya-zastosunkiv-obliku-vytrat-iphone-2026.mdx`.

## Technical work

Small and targeted — the i18n plumbing is mostly correct already. `lang` flows to `<html lang>` and
`og:locale` maps to `uk_UA` in `blog/src/layouts/BaseLayout.astro`.

Three defects, all scoped to Ukrainian rendering:

1. **Date locale hardcoded.** `blog/src/layouts/PostLayout.astro:29` calls
   `date.toLocaleDateString('en-US', ...)` regardless of post language, so uk posts show an English
   date. Format by the post's `lang`.
2. **UI strings hardcoded in English.** The "Get the app" header CTA in `PostLayout.astro`, plus
   `PostNav` and `EndCTA` components, render English on uk posts. Localize by `lang`.
3. **Blog index mixes locales.** `blog/src/pages/index.astro` lists all posts regardless of
   language, so the uk post sits unlabeled in an English list. Separate or label by locale.

Out of scope: locale route prefixes (`/blog/uk/…`). With one uk post and no plans for translation
pairs, the flat namespace is adequate. Revisit only if the uk track grows enough to justify it.

## Measurement

- **Google Search Console** — impressions, clicks, and position by query and country. The primary
  signal for whether the en strategy works.
- **App Store Connect** — installs attributed to web referrer.

Without these, "we grew in en" is a feeling, not a finding.

## Open questions

None blocking. Keyword validation happens as the first step of the implementation plan, and its
output re-orders the backlog rather than changing this design.
