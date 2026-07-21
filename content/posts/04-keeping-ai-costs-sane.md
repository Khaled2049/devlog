---
title: "Keeping the Lights On: How I Keep AI and Infrastructure Costs Sane"
date: 2026-03-10
draft: false
tags: ["thetaletribe"]
categories: ["thetaletribe"]
description: "The rate limits, serverless tools, and cost controls that stop a viral moment or a runaway loop from blowing up my bill overnight"
---

This is a passion project, and it's just me paying for it. So the finances are something I have to take seriously, even now, before there's really any traffic to speak of. The nightmare isn't failure — it's a weird kind of success: a story gets shared somewhere, real users actually show up, and I wake up to a bill big enough to make me regret ever letting people in for free. Long before that could happen, I started building barriers.

Will all of this catch every possible way things could go sideways? Probably not — I'm one person, and I'm sure there's some clever failure mode I haven't thought of yet. But at least I've _thought_ about it, at multiple layers, instead of hoping for the best. And as a final backstop under all of it, I've set up **budget alerts in GCP** that will automatically pull the plug on the whole project if spending ever crosses a hard dollar amount. So even in the scenario where every one of my own guardrails fails at once, there's a floor under the free-fall. Which means I can actually stop thinking about it and go write the app.

The thing I learned is that you don't defend against that with one dramatic off-switch. You defend against it with **layers** — a handful of independent limits, each catching a different kind of runaway, so that if one of them fails open the next one down still holds. TheTaleTribe has four of them, and they sit at four different points in the stack.

## Layer 1: A Per-User Daily Quota

The first check happens before a request even leaves my own backend. When you ask the AI to do anything, a Firebase Function looks at a **per-user counter in Firestore** — how many AI actions you've taken today — and compares it against a limit that defaults to **100 per person per day**.

The important detail is that this counter is _transactional_ and **fail-closed**. It's incremented inside a Firestore transaction, so two requests firing at the same moment can't both sneak through on the same count, and if the check itself errors out, the request is denied rather than allowed. A bug in my quota code should cost a user one blocked generation, never cost me a thousand unbilled ones.

If you've brought your own key (which I wrote about last post), this whole check is skipped — you're on your own provider, so there's nothing for me to ration.

## Layer 2: A Per-User Burst Limiter

The daily quota stops sustained overuse, but it doesn't stop someone from firing a hundred requests in ten seconds — a stuck retry loop, an over-eager script, a browser tab gone feral. So the gateway in front of the AI keeps a small **token-bucket rate limiter** for each user, defaulting to **10 requests per minute**.

It's an in-memory bucket per user that refills steadily; go over and you get a polite _slow down_ instead of a real AI call. Idle buckets get swept out over time so it never grows unbounded. It's cheap, it's boring, and it means no single user can turn a momentary glitch into a spike on my bill.

## Layer 3: The Bar Tab

The layer I think about the most is the one that handles actual spending, and the mental model I use for it is a bar tab.

When you send a message to the AI, before anything actually happens, the system sets aside a rough estimate of what that call is going to cost — kind of like a bartender putting a hold on your card. It reserves the **true ceiling** of the request (your prompt plus the maximum output it's allowed to produce). Then the real call happens, and once the actual usage comes back, the hold gets reconciled to match: a little handed back if the estimate was high, a little more taken if it ran over. Nobody gets charged before the system knows a call actually happened, and nobody slips through uncharged if it did.

And if something crashes in the middle, that hold **expires and releases on its own** after a few minutes — no manual cleanup, no stuck balances I have to go fix by hand. The whole reserve-commit-release dance runs as atomic scripts, so even under concurrent requests the math can't get corrupted.

## Layer 4: The Circuit Breaker

The three layers above all reason about _individual_ users. The thing that actually lets me sleep at night is a fourth, blunter check that sits above all of them and reasons about the platform as a whole.

Every AI provider gives you a certain number of free requests per day before they start charging real money. So there's one **global counter** that tracks how many requests the entire platform has made today, checked before a single user's credits even get touched — default ceiling **1,400 requests per day**. Once that counter hits the limit, the whole platform politely stops making platform-funded AI calls for the rest of the day, full stop, regardless of how many users show up or how enthusiastically they're generating chapters. The counter resets itself at midnight UTC and starts over.

It's not elegant, but it means there is a **hard ceiling** on what a bad day can cost me, and that ceiling doesn't move no matter how popular the app gets overnight. Honestly, while top-up is still a free MVP mint, this request cap — not anyone's credit balance — is the real guardrail.

## The Infrastructure That Makes It Cheap

Here's the part I'm quietly proud of: all of that accounting runs on infrastructure that costs me almost nothing when nobody's using it.

- **Upstash** — serverless Redis — holds every one of those live counters, the per-user rate-limit buckets, and the reservation "holds." It's billed per request and idles at essentially zero, so I'm not paying to keep a Redis box warm at 3 AM on the off chance someone writes a chapter.
- **Neon** — serverless Postgres — stores the **ledger**, the durable audit trail of every credit event (reserved, committed, released, purchased). Postgres gives me real transactional guarantees for the money side of things, and Neon's scale-to-zero model means I get that without paying for an always-on database.
- **Cloud Run**, which I've written about before, hosts the AI agent and the credit services themselves and scales down to nothing between requests.

The theme across all three is the same: I refuse to pay for _idle_. Redis, Postgres, and my application containers all bill me for work actually done and cost me next to nothing while the app sits quiet. That's the single biggest reason my monthly infrastructure bill for the entire backend is still in the single digits.

## The AI Half of the Bill

Cost control isn't only about _blocking_ calls — it's also about making the calls I do allow as cheap as they can be. A few things there:

- Every tool asks for only as many output tokens as its job needs — a full chapter gets a generous budget, an inline suggestion or a wizard hint gets a tiny one — so I'm never paying for a novel's worth of tokens to answer a one-line prompt.
- The context builder caps how much of your story gets stuffed into each prompt, keeping only the most relevant, most recent entities and eliding the rest, so prompts don't quietly bloat as a story grows to hundreds of characters and places.
- The platform default is a small, fast, cheap model, and **BYOK** pulls my heaviest users off the shared bill entirely — the people generating the most content are, cost-wise, the cheapest users I have.
