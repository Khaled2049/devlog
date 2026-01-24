#!/bin/bash

# Hugo Blog Setup Script
# This script helps you set up your Hugo blog with PaperMod theme

set -e

echo "🚀 Setting up Hugo blog with PaperMod theme..."
echo ""

# Check if Hugo is installed
if ! command -v hugo &> /dev/null; then
    echo "❌ Hugo is not installed."
    echo "Please install Hugo Extended from: https://gohugo.io/installation/"
    exit 1
fi

# Check Hugo version
HUGO_VERSION=$(hugo version | sed -n 's/.*v\([0-9]*\.[0-9]*\).*/\1/p' | head -1)
echo "✅ Found Hugo version $HUGO_VERSION"
echo ""

# Prompt for GitHub username
read -p "Enter your GitHub username: " GITHUB_USERNAME

if [ -z "$GITHUB_USERNAME" ]; then
    echo "❌ GitHub username is required"
    exit 1
fi

echo ""
echo "📝 Updating configuration files..."

# Update hugo.toml
sed -i '' "s/YOUR_GITHUB_USERNAME/$GITHUB_USERNAME/g" hugo.toml
echo "✅ Updated hugo.toml"

# Update README
sed -i '' "s/YOUR_GITHUB_USERNAME/$GITHUB_USERNAME/g" README.md
echo "✅ Updated README.md"

echo ""
echo "📦 Adding PaperMod theme as submodule..."

# Add theme submodule
if [ ! -d "themes/PaperMod" ]; then
    git submodule add --depth=1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
    git submodule update --init --recursive
    echo "✅ PaperMod theme added"
else
    echo "⚠️  PaperMod theme already exists"
fi

echo ""
echo "✨ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Run 'hugo server -D' to preview your site locally"
echo "2. Create a GitHub repository named 'devlog'"
echo "3. Push your code:"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial commit: Hugo blog with PaperMod'"
echo "   git branch -M main"
echo "   git remote add origin https://github.com/$GITHUB_USERNAME/devlog.git"
echo "   git push -u origin main"
echo "4. Enable GitHub Pages in your repository settings"
echo ""
echo "Your blog will be available at: https://$GITHUB_USERNAME.github.io/devlog/"
