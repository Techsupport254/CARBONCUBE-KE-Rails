#!/bin/bash

# GitHub Personal Access Token Setup Script
# Replace YOUR_USERNAME and YOUR_PAT with your actual values

echo "Setting up GitHub authentication with Personal Access Token..."
echo ""

# Prompt for username and PAT
read -p "Enter your GitHub username: " GITHUB_USERNAME
read -s -p "Enter your Personal Access Token: " GITHUB_PAT
echo ""

# Configure frontend remote
echo "Configuring frontend remote..."
cd /Users/Quaint/Desktop/carbon-v2/frontend-carbon
git remote set-url origin "https://${GITHUB_USERNAME}:${GITHUB_PAT}@github.com/Techsupport254/frontend-carbon.git"

# Configure backend remote
echo "Configuring backend remote..."
cd /Users/Quaint/Desktop/carbon-v2/backend
git remote set-url origin "https://${GITHUB_USERNAME}:${GITHUB_PAT}@github.com/Techsupport254/CARBONCUBE-KE-Rails.git"

echo ""
echo "✅ GitHub remotes configured with Personal Access Token!"
echo ""
echo "Testing authentication..."

# Test frontend push
cd /Users/Quaint/Desktop/carbon-v2/frontend-carbon
echo "Testing frontend repository..."
git ls-remote origin HEAD >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Frontend authentication successful!"
else
    echo "❌ Frontend authentication failed!"
fi

# Test backend push
cd /Users/Quaint/Desktop/carbon-v2/backend
echo "Testing backend repository..."
git ls-remote origin HEAD >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Backend authentication successful!"
else
    echo "❌ Backend authentication failed!"
fi

echo ""
echo "🎉 Setup complete! You can now run the deployment script."
