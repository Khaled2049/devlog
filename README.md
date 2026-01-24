# Khaled's Dev Log

Automated weekly development blog powered by Hugo and PaperMod theme.

## Local Setup

### Prerequisites

- [Hugo Extended](https://gohugo.io/installation/) (v0.140.2 or later)
- Git
- A GitHub account

### Installation

1. **Clone this repository:**
   ```bash
   git clone https://github.com/khaled2049/devlog.git
   cd devlog
   ```

2. **Add PaperMod theme as a submodule:**
   ```bash
   git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
   git submodule update --init --recursive
   ```

3. **Update the configuration:**
   Edit `hugo.toml` and replace:
   - `khaled2049` with your actual GitHub username
   - Update the `baseURL` if using a custom domain

4. **Run locally:**
   ```bash
   hugo server -D
   ```
   Visit `http://localhost:1313/` to see your site.

## Deployment to GitHub Pages

### Step 1: Create GitHub Repository

1. Create a new repository on GitHub named `devlog` (or your preferred name)
2. Make it public
3. Don't initialize with README, .gitignore, or license (we already have these)

### Step 2: Push Your Code

```bash
# From your blog directory
git init
git add .
git commit -m "Initial commit: Hugo blog with PaperMod"
git branch -M main
git remote add origin https://github.com/khaled2049/devlog.git
git push -u origin main
```

### Step 3: Enable GitHub Pages

1. Go to your repository on GitHub
2. Click **Settings** → **Pages**
3. Under **Source**, select **GitHub Actions**
4. The workflow will automatically run and deploy your site

Your site will be available at: `https://khaled2049.github.io/devlog/`

## Adding New Posts

Create a new post manually:

```bash
hugo new content/posts/week-5-2026.md
```

Or wait for your automation system to generate them!

### Post Front Matter Template

```yaml
---
title: "Week X: Your Title Here"
date: 2026-01-23T10:00:00-07:00
draft: false
tags: ["devlog", "tag2", "tag3"]
categories: ["weekly-update"]
---
```

## Project Structure

```
devlog-blog/
├── .github/
│   └── workflows/
│       └── hugo.yml          # GitHub Actions deployment
├── content/
│   ├── posts/
│   │   └── week-4-2026.md   # Your blog posts
│   └── search.md            # Search page
├── themes/
│   └── PaperMod/            # Theme submodule
├── .gitignore
├── .gitmodules
├── hugo.toml                # Hugo configuration
└── README.md
```

## Automation Integration

This blog is designed to work with the automated dev log system:

1. **Git hooks** capture commits from your projects
2. **Supabase** stores the commit data
3. **n8n** generates weekly Markdown posts
4. **GitHub Actions** automatically deploys when new posts are pushed

Posts should be added to `content/posts/` with the naming pattern: `week-X-2026.md`

## Customization

### Changing Theme Colors

Create `assets/css/extended/custom.css` and add your styles.

### Adding a Profile Picture

1. Add your image to `static/images/avatar.png`
2. Update `hugo.toml`:
   ```toml
   [params.profileMode]
     enabled = true
     title = "Khaled"
     imageUrl = "/images/avatar.png"
   ```

### Adding Analytics

Update `hugo.toml`:
```toml
[params.analytics.google]
  SiteVerificationTag = "YOUR_TAG"
```

## Troubleshooting

### Theme Not Loading

Make sure you've initialized the submodule:
```bash
git submodule update --init --recursive
```

### GitHub Actions Failing

Check that GitHub Pages is enabled in repository settings and set to "GitHub Actions" source.

### Base URL Issues

Ensure your `baseURL` in `hugo.toml` matches your GitHub Pages URL exactly.

## License

Content: Your choice
Theme (PaperMod): MIT License
