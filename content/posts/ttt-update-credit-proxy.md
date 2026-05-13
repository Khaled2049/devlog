---
title: "TTT Update: Credit Proxy"
date: 2026-05-09T18:35:39-06:00
draft: false
tags: ["devlog"]
categories: ["weekly-update"]
---

## The Problem

I've been building AI features into [TheTaleTribe](https://thetaLetribe.com) from the start. The AI side of things started pretty naively: I had a free Gemini API key and a hardcoded limit of 10 AI requests per user. That was it. For local dev I ran Ollama, so I could use it as much as I wanted. Simple, but obviously not something you can scale or ship.

The problem is that AI features on a writing platform aren't a one-off thing. Writers want to ask the AI for feedback on a chapter, generate a scene, brainstorm names for a character. That's not 10 requests that's potentially dozens per session. So the "you get 10 per day" model was dead on arrival, also not all ai requests consumed the same number of tokens.

As a software dev I figured I start looking at how the tools I use daily use overcome this problem. Most of them use a tiered subscription plans with monthly token limits. That works at scale, but it assumes you're charging users real money from day one. For an early-stage platform with a free tier and a handful of active users, I needed something lighter something that lets free users access AI features within a budget I can actually afford, without burning through my API credits overnight.

---

## The Math

Before building anything, I needed to understand what this actually costs. Here's the pricing landscape for the LLM APIs I was considering:

| Provider  | Model                        | Input (per 1M tokens) | Output (per 1M tokens) |
| --------- | ---------------------------- | --------------------- | ---------------------- |
| Google    | Gemini 2.0 Flash (free tier) | $0                    | $0                     |
| Google    | Gemini 2.0 Flash (paid)      | $0.075                | $0.30                  |
| OpenAI    | GPT-4o-mini                  | $0.15                 | $0.60                  |
| Anthropic | Claude Haiku 4.5             | $0.80                 | $4.00                  |
| Anthropic | Claude Sonnet 4.6            | $3.00                 | $15.00                 |

A typical TTT interaction isn't a short question it's a writer asking a question and then I insert the chapter, plot and other info and then they get feedback. That's a very different token profile than a chatbot one-liner:

```
~3,000-word chapter + ~50-word question = ~3,050 words input
3,050 words × 1.3 ≈ 4,000 input tokens

~300-word response × 1.3 ≈ 400 output tokens

≈ 4,400 tokens / interaction
```

Input dominates. At 20 interactions per month, that's **80,000 input tokens** and **8,000 output tokens** per user.

| Provider                | Monthly cost per user | 100 users | 1,000 users | 10,000 users |
| ----------------------- | --------------------- | --------- | ----------- | ------------ |
| Gemini 2.0 Flash (paid) | $0.008                | $0.84     | $8.40       | $84.00       |
| GPT-4o-mini             | $0.017                | $1.68     | $16.80      | $168.00      |
| Claude Haiku 4.5        | $0.096                | $9.60     | $96.00      | $960.00      |
| Claude Sonnet 4.6       | $0.360                | $36.00    | $360.00     | $3,600.00    |

Gemini Flash is cheap at scale. But Claude Sonnet at 10,000 users is **$3,600/month** — a real number that would hurt. And this is only 20 interactions per month per user. Heavy users doing daily feedback sessions would push that further.

This is exactly why model choice matters. The platform defaults to Gemini Flash. Users who want Sonnet or GPT-4 can use BYOK (bring your own key) and pay their own API bill. That keeps the platform's infrastructure costs predictable.

The free tier has hard rate limits:

- **1,500 requests per day** (RPD)
- **1,000,000 tokens per minute** (TPM)

At 20 interactions/month per user, 1,500 RPD supports about **2,250 users on the free tier**.

The credit system solves this in a few concrete ways:

**It gates the API call before it happens.** Credits are reserved _before_ the LLM request is made. If a user is out of credits, the gateway rejects the request at step 3 — no API call is made, no money is spent. Unlike a post-hoc rate limiter, this means a user can never accidentally cost me money just by hammering the endpoint.

**It makes the free tier's ceiling explicit.** Gemini's free tier allows 1,500 requests/day. With credits, each user has a finite balance. If I grant 50,000 credits to each new user and a chapter interaction costs ~4,400 tokens, that's ~11 free interactions per user. Spread across 2,000 users who don't all interact every day so I'll stay well within the 1,500 RPD limit.

**It gives you real data for the upgrade decision.** Every interaction is logged to the ledger with the actual token count. At any point you can query: how many total tokens were consumed this month? What's the equivalent Gemini Flash paid cost? When that number approaches "worth the billing hassle", you switch the env var from the free key to the paid key. The rest of the system doesn't change.

**Tiers are just credit top-ups.** Adding a paid plan later doesn't require touching the reservation logic. A "Pro" tier is just `POST /v1/credits/purchase` with a larger number of credits when someone pays. Free tier = `INITIAL_CREDITS`. Pro tier = initial grant + purchase on subscription. The gateway doesn't know or care which tier a user is on — it only sees a balance.

**BYOK is the escape valve for expensive models.** Users who want Claude Sonnet or GPT-4 can bring their own API key. The platform pays nothing for those requests — they completely bypass the usage service. The ledger still logs them for audit purposes, but there's zero infrastructure cost to the platform. This means I can offer access to better models without eating $3,600/month in API bills.

---

## The Architecture

I decided to build this as a standalone service rather than tangling it into TTT's codebase. Two reasons: (1) this is a problem other small platforms will hit, and (2) I wanted to write it in Go, which felt like the right language for a small, fast, internal HTTP proxy with no framework overhead.

The result is four microservices, each a single `main.go` file:

```
                     ┌──────────────────────────────────────────┐
  Client App  ──────▶│           Gateway  :8080                 │
  (TTT agents)       └────┬───────────────┬───────────────┬─────┘
                          │               │               │
                    reserve/commit   emit events     call LLM
                          │               │               │
               ┌──────────▼──┐   ┌────────▼────┐  ┌──────▼──────┐
               │  Usage :8081│   │ Ledger :8083│  │LLMProxy:8082│
               └──────────┬──┘   └────────┬────┘  └──────┬──────┘
                          │               │               │
                    ┌─────▼─────┐  ┌──────▼──────┐       │
                    │  Redis 7  │  │ Postgres 16 │       ▼
                    └───────────┘  └─────────────┘  Gemini / OpenAI /
                                                    Anthropic / Ollama
```

**Gateway** (`:8080`) — the only public-facing service. Receives generate requests, orchestrates the credit reservation lifecycle, and proxies to LLM Proxy.

**Usage** (`:8081`) — owns credit balances. All mutations run as Redis Lua scripts for atomicity. New users get a free credit grant on their first request (via `SetNX`, so it's atomic and happens exactly once). The default is 10,000 — fine for short prompts, but for TTT where users send full chapters as context (~4,000 tokens each), that's only about 2 interactions. In practice I'll bump `INITIAL_CREDITS` to something like 50,000–100,000 to give new users a meaningful free trial (~10–20 chapter interactions).

**LLM Proxy** (`:8082`) — wraps the upstream AI providers behind a single interface. Supports Gemini, OpenAI, Anthropic, Ollama, and a mock provider for local dev.

**Ledger** (`:8083`) — append-only audit trail in Postgres. Every credit event (reserved, committed, released) is written here with an idempotency key to prevent duplicates.

---

## The Request Flow

### Platform-Credits Path (default)

This is what happens when a TTT user with a platform-managed balance makes an AI request:

```
1.  Gateway receives POST /v1/generate
        { user_id, prompt, max_output_tokens }

2.  Estimate token cost
        prompt_tokens = words(prompt) × 1.3
        reserved = prompt_tokens + max_output_tokens   ← conservative

3.  Reserve credits in Usage (Redis Lua)
        DECRBY user:credits:<userID>  reserved
        HSET reservation:<resID>  amount reserved  status "reserved"
        EXPIRE reservation:<resID>  180s          ← TTL prevents leaks

4.  Emit credits_reserved → Ledger (fire-and-forget)

5.  POST to LLM Proxy → upstream provider

    On LLM failure:
    5a. Release reservation (INCRBY balance, set status "released")
    5b. Emit credits_released → Ledger

6.  Commit with actual token count (Lua reconciles over/under-spend)
        if actual < reserved: refund the difference
        if actual > reserved: deduct the extra (if balance allows)

7.  Emit credits_committed → Ledger

8.  Return response to client with estimated vs. actual credits
```

The reservation TTL (step 3) is the key safety mechanism. If the gateway crashes after reserving but before committing, Redis automatically cleans up the reservation after 180 seconds and the credits are refunded. No manual cleanup needed.

### BYOK Path (Bring Your Own Key)

Power users can bypass platform credits entirely by supplying their own API key in the request:

```
1.  Gateway receives POST /v1/generate
        { user_id, prompt, byok_provider, byok_api_key, byok_model }

2.  Detect BYOK: byok_provider + byok_api_key present → skip Usage entirely

3.  POST to LLM Proxy with BYOK fields
        LLM Proxy instantiates a fresh provider for this request only
        Uses the caller's key, not the platform key

4.  Emit byok_generate → Ledger (audit only — no credit impact)

5.  Return response to client
```

BYOK is useful for TTT's future pro tier — users who have their own API keys and want to use a more powerful model without being throttled by platform credits.

---

## Token Estimation

> This is good enough for now. Once TTT hits 100 users I'll have real usage data actual prompt lengths, response lengths, model distribution and can replace the heuristic with something more accurate (likely the provider's own token-count API). At that point I'll also know whether the estimation skew is consistently over or under, which matters for credit fairness.

Real tokenizers (like tiktoken) require loading a vocabulary file and running BPE encoding. That's overkill for my MVP where the goal is an approximation that's close enough for billing fairness.

The heuristic used here:

```go
// ~1.3 tokens per word — accurate enough for English prose, dependency-free
func Estimate(text string) int64 {
    words := int64(len(strings.Fields(text)))
    return max(1, words*13/10)
}
```

Why 1.3 tokens/word? It's the empirically observed average for English prose in GPT-style tokenizers. Words like "running" are one token; longer words like "microservices" might be two. Contractions, punctuation, and numbers add some overhead. 1.3 is a reasonable middle ground.

For the reservation, we use a conservative estimate: `prompt_tokens + max_output_tokens`. We don't know how long the response will actually be, so we hold the maximum. At commit time the actual output is measured and the difference is reconciled:

```
Example:
  prompt:            "Write a scene where the hero crosses the bridge"
  words:             10  →  tokens: 13
  max_output_tokens: 256
  reserved:          13 + 256 = 269 credits

  actual response:   180 words  →  tokens: 234
  reconcile:         reserved (269) - actual (234) = 35 credits refunded
  final charge:      234 credits
```

The reconciliation runs as a Lua script in Redis, so there's no window for a race condition between the balance read and the write.

---

## The Credit Reservation System

The usage service implements a classic **reserve → commit/release** pattern. All three operations are Redis Lua scripts, which means they execute atomically on the Redis server — no TOCTOU races.

**Reserve:** checks balance, decrements it, creates a reservation hash with a TTL.

```lua
-- simplified
if balance < amount then return {0, balance} end
DECRBY  user:credits:<userID>   amount
HSET    reservation:<resID>     user_id .. amount .. "reserved"
EXPIRE  reservation:<resID>     ttl_seconds
return {1, new_balance}
```

**Commit:** reconciles estimated vs. actual spend, marks reservation committed.

```lua
-- if actual > reserved: deduct extra from balance (fails if insufficient)
-- if actual < reserved: refund the difference to balance
HSET reservation:<resID>  status "committed"  amount actual
```

**Release:** refunds the full reserved amount to the balance.

```lua
INCRBY  user:credits:<userID>   reserved_amount
HSET    reservation:<resID>     status "released"
```

New user bootstrap is also atomic: `SetNX user:credits:<userID> <INITIAL_CREDITS>` sets the balance only if the key doesn't exist. The first reservation triggers this automatically — no separate signup step needed. With the default of 10,000 bumped to 50,000 for TTT, that's roughly 11 free chapter interactions before a user needs to purchase credits.

---

## Security

The current implementation is designed for **internal use** — the gateway is called by TTT's own backend services (novelsync-agents), not directly by browsers. That shapes the security model significantly.

**What's in place:**

- Redis Lua scripts prevent race conditions on credit mutations
- Reservation TTL (180s) prevents credit leaks on gateway crashes
- Ledger idempotency (`ON CONFLICT (idempotency_key) DO UPDATE`) deduplicates audit events
- BYOK requests are still audited in the ledger even though they skip platform credits
- `SetNX` ensures initial credits are granted exactly once

---

## The Scaling Math

Here's what this looks like in practice at different user counts, assuming Gemini 2.0 Flash paid and 20 chapter-feedback interactions/user/month (~4,400 tokens each):

| Users  | Monthly API cost | Free credits given away (50k/user, one-time) | Net cost |
| ------ | ---------------- | -------------------------------------------- | -------- |
| 100    | $0.84            | 100 × 50,000 = 5M tokens → $0.375            | ~$1.22   |
| 1,000  | $8.40            | 10M tokens (new users only) → $0.75          | ~$9.15   |
| 10,000 | $84.00           | 50M tokens (new users only) → $3.75          | ~$87.75  |

The one-time credit grant for new users (at 50,000 tokens on Gemini Flash) costs about $0.004 per user — the price of someone's first ~11 chapter interactions. That's a reasonable acquisition cost.

**When does the free API tier break?**

Gemini's free tier allows 1,500 requests/day. At 20 interactions/user/month (≈ 0.67/day per user):

```
free_tier_capacity = 1,500 RPD / 0.67 req/user/day ≈ 2,238 users
```

Under ~2,200 active users, the free API key handles everything. Above that, switching to the paid tier costs $84/month at 10k users. The credit system gives visibility into when that threshold is approaching, and makes the switch painless — just update the env var and pay the bill.

**If I wanted to sell credits:**

With chapter-sized prompts, 1,000 tokens = ~0.23 interactions. At a 3× markup on Gemini Flash:

```
Platform cost:  $0.00000825 per token  ($8.25 per 1M)
Sell at:        $0.000025   per token  ($25 per 1M)
$10 purchase → 400,000 tokens → ~90 chapter interactions
```

That's reasonable pricing for a writing platform — $10 gets a user roughly 90 AI feedback sessions, which at one chapter per week is almost two years of use.

That's probably too generous for a credit purchase, but it shows the unit economics are very healthy at the Gemini Flash price point. The credit system makes it easy to tune the pricing later.

---

## What's Next

A few things I want to add before this is production-ready for TTT:

- **Service-to-service auth** — shared secret between novelsync-agents and the gateway
- **Rate limiting** — per-user token bucket to prevent abuse even with valid auth
- **Credit alerts** — webhook or event when a user's balance drops below a threshold
- **Dashboard** — query the ledger to show users their usage history
- **True idempotency** — make the full generate operation idempotent, not just the ledger events
