---
title: "Teaching the AI to Remember Your Story"
date: 2026-04-05
draft: false
tags: ["thetaletribe"]
categories: ["thetaletribe"]
description: "How TheTaleTribe's AI keeps track of your characters, your style, and what already happened without forgetting the plot"
---

What I really wanted was for the AI to actually _know what's going on_ in your story. Mention a character and it should already know who they are and what they want — assuming you've told it, and assuming it doesn't just make something up on the spot. That sounds simple, but getting it to hold a whole novel in its head without either forgetting things or hallucinating them took me longer than almost anything else I've built on TheTaleTribe. It's easily the most complicated part of the whole project, and it's the piece I'm probably proudest of.

The naive fix is obvious and also doesn't work. Just take every chapter, every character, every plot note you've written and stuff the whole thing into the prompt every single time you send a message. That's fine for a story that's three chapters long. It falls apart completely on a real novel, sending dozens of chapter bodies to the model on every single message, which is slow, expensive, and mostly pointless because the model doesn't need chapter four to answer a question about chapter fifty-five.

## Remembering the Way a Person Does

What I ended up building mirrors how a person actually holds a long story in their head. You don't replay the whole book every time someone asks you a question about it. You keep a small working sense of what's happening _right now_, and you dig up specific details only when something actually calls for them.

So the memory comes in two temperatures. There's a **lightweight layer that's always present** — the current scene, the characters in it, your writing style and tone — and then a **deeper layer that only gets pulled in when it's relevant**: facts the AI has picked up about your world, summaries of things that happened earlier, and the actual passages from your chapters that relate to whatever you just asked. Ask about how a character escaped a tower and it goes and finds the handful of paragraphs that are actually about that tower, not the chapters about the marketplace or the ending.

The part I like most is that it doesn't just remember what you wrote, it reflects on what _it itself_ said. After it responds to you — in the background, after you've already gotten your answer — it quietly looks back at that exchange and updates its own notes: this happened, this fact came up, this is worth remembering next time. That happens after the fact, so it never slows down the response you're actually waiting on, and if that background step ever fails for some reason, it fails quietly rather than breaking your chat.

## What I Got Wrong Building This

The version I just described is not the version I first shipped. The gap between them is basically a list of my own mistakes, and the honest ones are worth writing down.

**I built the same thing twice without noticing.** The searchable index over your chapters and the "facts about your world" memory are, underneath, the _exact same operation_ — turn text into a vector, store it, later find the closest matches — but I'd written them as two separate pieces of code, with two different ways of failing and two places the math could quietly drift apart. Worse, the memory side was doing the search the brute-force way: comparing your question against every stored fact, one by one. On a small story you'd never notice. On a big one it's exactly the kind of quietly-scaling cost I keep swearing to avoid. I tore both out and rebuilt them on **one shared primitive** that does the search the fast, indexed way (a real vector index, not a linear scan), so there's now a single implementation, a single failure mode, and no accidental full scans hiding in a corner.

**I was paying to understand your question more than once.** The chapter search and the world-facts search were each turning your message into a vector on their own — two identical embedding calls where one would do. Now the message gets embedded a single time at the top of the turn and the layers that need it share that one result. A small thing, but it's a free saving on every single chat message, and free savings add up.

**I treated memory as if it had to succeed.** Early on, if the fancy memory layer hiccuped, it could take the _whole_ chat reply down with it — which is an absurd trade: you lose the ability to talk to the AI at all because an optional enhancement failed. Now every one of these layers is **best-effort**. If retrieval fails, or the vector index isn't ready yet, or the background reflection throws, the chat just falls back to the basic always-on context and answers you anyway. The nice-to-have is allowed to break; the core thing you're actually doing never is.

## Why It Was Worth It

Getting this right meant a system that costs close to nothing to run and stays flat no matter how long your book gets, which matters a lot given everything I wrote about cost control in the last post. But honestly the bigger win for me isn't the cost — it's the first time you ask the AI something about a character you introduced weeks ago and it _just knows_, the same way a person who actually read your book would.
