# Quick Start Guide

## Installation (5 minutes)

1. **Download Hugo Extended:**
   - macOS: `brew install hugo`
   - Windows: Download from https://gohugo.io/installation/windows/
   - Linux: Download from https://gohugo.io/installation/linux/

2. **Download the blog files** (from Claude) to your local machine

3. **Run the setup script:**
   ```bash
   cd devlog-blog
   chmod +x setup.sh
   ./setup.sh
   ```
   Enter your GitHub username when prompted.

4. **Test locally:**
   ```bash
   hugo server -D
   ```
   Open http://localhost:1313 in your browser

## Deployment (5 minutes)

1. **Create GitHub repository:**
   - Go to https://github.com/new
   - Name it `devlog`
   - Make it public
   - Don't initialize with any files

2. **Push your code:**
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/devlog.git
   git push -u origin main
   ```

3. **Enable GitHub Pages:**
   - Go to your repo → Settings → Pages
   - Source: Select "GitHub Actions"
   - Wait 2-3 minutes for deployment

4. **Visit your site:**
   `https://YOUR_USERNAME.github.io/devlog/`

## Creating New Posts

### Manual Method:
```bash
hugo new content/posts/week-5-2026.md
```

### For Your Automation:
Your n8n workflow should create files in `content/posts/` with this format:

**Filename:** `week-X-YYYY.md` (e.g., `week-5-2026.md`)

**Content:**
```markdown
---
title: "Week 5: Your Generated Title"
date: 2026-01-30T10:00:00-07:00
draft: false
tags: ["devlog", "go", "javascript"]
categories: ["weekly-update"]
---

Your LLM-generated content here...
```

## Common Commands

- **Start dev server:** `hugo server -D`
- **Build site:** `hugo`
- **Create new post:** `hugo new content/posts/my-post.md`
- **Update theme:** `git submodule update --remote --merge`

## File Structure for Automation

When your n8n workflow creates posts, they should go here:
```
devlog-blog/
└── content/
    └── posts/
        ├── week-4-2026.md
        ├── week-5-2026.md  ← n8n creates here
        └── week-6-2026.md
```

After n8n pushes to GitHub, the workflow automatically deploys.

## Troubleshooting

**"Theme not found"**
```bash
git submodule update --init --recursive
```

**"Site not updating on GitHub Pages"**
- Check Actions tab in your repo for build errors
- Verify baseURL in hugo.toml matches your GitHub Pages URL

**"Posts not showing"**
- Make sure `draft: false` in the post front matter
- Check that the date is not in the future

## Next Steps

Once your blog is deployed:
1. ✅ Blog is live
2. 🔨 Build Phase 1: Git hooks to capture commits
3. 💾 Build Phase 2: Supabase storage
4. 🤖 Build Phase 3: n8n automation
5. 🚀 Build Phase 4: Auto-deploy posts

Your n8n workflow will create markdown files in `content/posts/` and push them to GitHub, triggering automatic deployment.
