#!/bin/bash
# Blase & Darm Manager — Projekt Setup
# 
# Dieses Script installiert XcodeGen (falls nötig) und
# generiert ein sauberes Xcode-Projekt.

echo "🔧 Blase & Darm Manager — Projekt generieren"
echo ""

# Check for xcodegen
if ! command -v xcodegen &> /dev/null; then
    echo "📦 XcodeGen wird installiert..."
    brew install xcodegen
    echo ""
fi

# Generate project
echo "⚙️  Xcode-Projekt wird generiert..."
xcodegen generate

echo ""
echo "✅ Fertig! Öffne BlaseUndDarm.xcodeproj"
echo ""
echo "Nächste Schritte:"
echo "  1. open BlaseUndDarm.xcodeproj"
echo "  2. Signing & Capabilities → dein Team auswählen"
echo "  3. Cmd+R zum Testen"
echo ""
