#!/bin/bash

# Valentine's Email Campaign CSV Generator
# Quick script to generate seller data for Mailjet

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💘 Valentine's Email Campaign CSV Generator"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Choose an option:"
echo ""
echo "1. Generate FULL CSV (all active sellers)"
echo "2. Generate TEST CSV (Victor Quaint only)"
echo "3. View campaign statistics"
echo "4. View seller segments"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
  1)
    echo ""
    echo "🚀 Generating full CSV with all active sellers..."
    echo ""
    bundle exec rails valentines:generate_csv
    echo ""
    echo "✅ Done! Check backend/tmp/ for the CSV file"
    ;;
  2)
    echo ""
    echo "🧪 Generating test CSV (Victor Quaint only)..."
    echo ""
    bundle exec rails valentines:test_csv
    echo ""
    echo "✅ Done! Check backend/tmp/ for the test CSV"
    ;;
  3)
    echo ""
    bundle exec rails valentines:stats
    ;;
  4)
    echo ""
    bundle exec rails valentines:segment
    ;;
  *)
    echo ""
    echo "❌ Invalid choice. Please run again and choose 1-4."
    exit 1
    ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
