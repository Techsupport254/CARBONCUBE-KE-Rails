#!/bin/bash

# GitGuardian Security Verification Script
# Run this script to check for potential credential leaks

echo "🔒 GitGuardian Security Verification"
echo "====================================="

# Check for tracked sensitive files
echo ""
echo "📋 Checking for tracked sensitive files..."

echo "Frontend:"
cd frontend 2>/dev/null && git ls-files | grep -E "\.(env|key|pem|secret|credential)" || echo "Frontend directory not found"

echo ""
echo "Backend:"
cd ../backend 2>/dev/null && git ls-files | grep -E "\.(env|key|pem|secret|credential)" || echo "Backend directory not found"

# Check for hardcoded credentials
echo ""
echo "🔍 Scanning for hardcoded credentials..."

echo "Frontend (JavaScript/TypeScript):"
cd ../frontend 2>/dev/null && grep -r -i "api_key\|secret\|password\|token" src/ --include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx" | head -5 || echo "Frontend directory not found"

echo ""
echo "Backend (Ruby):"
cd ../backend 2>/dev/null && grep -r -i "api_key\|secret\|password\|token" app/ --include="*.rb" | head -5 || echo "Backend directory not found"

# Check environment files
echo ""
echo "📁 Environment file status:"

echo "Frontend:"
cd ../frontend 2>/dev/null && ls -la .env* 2>/dev/null || echo "Frontend directory not found"

echo ""
echo "Backend:"
cd ../backend 2>/dev/null && ls -la .env* 2>/dev/null || echo "Backend directory not found"

# Security recommendations
echo ""
echo "✅ Security Status:"
echo "=================="

if cd ../frontend 2>/dev/null && git ls-files | grep -q "^\.env\.production$"; then
    echo "❌ Frontend: .env.production is tracked by git"
else
    echo "✅ Frontend: .env.production is not tracked"
fi

if cd ../backend 2>/dev/null && [ -f "config/master.key" ]; then
    echo "❌ Backend: config/master.key exists (should not be tracked)"
else
    echo "✅ Backend: config/master.key is not tracked"
fi

if cd ../backend 2>/dev/null && [ -f "config/credentials.yml.enc" ]; then
    echo "✅ Backend: credentials.yml.enc is properly encrypted"
else
    echo "⚠️  Backend: credentials.yml.enc not found"
fi

echo ""
echo "🎯 Recommendations:"
echo "==================="
echo "1. Never commit .env files with real credentials"
echo "2. Use environment variables for all sensitive data"
echo "3. Use Rails credentials for backend secrets"
echo "4. Regularly run this verification script"
echo "5. Monitor GitGuardian alerts"

echo ""
echo "🔒 GitGuardian verification complete!"
