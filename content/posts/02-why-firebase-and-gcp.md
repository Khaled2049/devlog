---
title: "Why I Bet on Firebase and GCP as a Solo Builder"
date: 2026-01-25
draft: false
tags: ["thetaletribe"]
categories: ["thetaletribe"]
description: "Why I picked Firebase and GCP for TheTaleTribe instead of hand-rolling my own backend"
---

## From Side Project to Full-Time Obsession

I started building TheTaleTribe a long time ago. Initially, it was just a side project—a playground for experimenting with new AI models. While there are plenty of public benchmarks out there, I prefer having my own. Building actual features became my way of stress-testing the latest and greatest LLMs to judge their true capabilities.

The project started with Gemini. If you look at the first video on my YouTube channel, you can see how rough the app looked at the start, but the core idea was there. This was right around the time ChatGPT was first becoming popular.

Obviously, I didn't know I'd end up spending _this_ much time building it, but I kept at it, continually adding more and more features. Because I was flying completely solo, I had to wear every hat: designer, product manager, backend developer, frontend dev, and even the marketing guy. It was just me, some free time after work, and a growing list of features I wanted to build.

This dynamic was the main reason I chose **Google Cloud Platform (GCP)**. First and foremost, side projects are for learning, and I hadn't used GCP much before. I could have easily chosen AWS, but I figured it would be fun to tackle a new ecosystem. I knew I probably wouldn't have a massive user base right out of the gate, but I still wanted to build something scalable. Plus, the local emulators that Firebase and GCP provide seemed incredibly cool.

## The Infrastructure Tax

I've used AWS on other projects before, and honestly, it's fine. It's powerful, but it's also _a lot_. You end up wiring together EC2 or ECS, an RDS instance, some kind of message queue, and maybe an API Gateway—and _you_ are the one who has to keep all of it patched, scaled, and monitored.

For a dedicated team, that's a reasonable tradeoff. For one guy shipping features at night, it's an infrastructure tax I simply didn't want to pay.

## The Firebase and GCP Bet

Firebase and GCP felt like the exact opposite of that heavy setup. Two services, in particular, completely changed how I thought about the app's architecture:

### 1. Real-Time Magic with Firestore

A big chunk of TheTaleTribe relies on background processing—chapter generation being the obvious example. Kicking off a long-running AI task and waiting for it to finish used to mean building a polling loop, standing up a WebSocket server, or wiring in a complex pub/sub system.

With **Firestore**, I just write a "job" document. The client attaches a listener to it, and the second the backend updates the status, the UI updates instantly. No polling, no extra infrastructure, and zero extra code to write and maintain. It's genuinely one of those cases where the platform gives you something for free that would otherwise require building an entirely separate project.

### 2. Scaling to Zero with Cloud Run

**Cloud Run** was the other half of the equation. The AI agent service and the credit metering services both run there, and they scale down to basically zero when nobody is using the app.

I'm not paying for idle EC2 instances sitting around waiting for traffic that might arrive at 3 PM, or might not come until next week. When someone opens the app and asks the AI to write a chapter, a container spins up, does the work, and eventually spins back down. At TheTaleTribe's current traffic levels, my monthly infrastructure bill for the entire backend is in the single digits. That isn't because I've done anything particularly clever—it's just because I picked tools that don't charge me for sitting idle.

## The Tradeoffs

To be clear, there is a real cost to this approach. You give up a certain degree of control, and you become tied pretty deeply into Google's way of doing things. Firestore's NoSQL query model also takes some getting used to if you're coming from a traditional relational database background. I definitely hit moments early on where I desperately wanted a simple `JOIN` and had to completely restructure my data model instead.

But those are tradeoffs I am completely happy to make.

As a solo builder, my scarcest resource isn't compute power or bandwidth—it's **my own attention**. Every piece of undifferentiated backend work that Firebase quietly erased for me is attention I got to spend on the writing tools and AI features that actually make TheTaleTribe worth using.
