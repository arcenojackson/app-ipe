#!/bin/bash
set -e

PEXELS_API_KEY="lPOKBczwM78ipvUUO9zwbU2JTCevDxH23edZ8dIa8kYg6GUVVGit1eYn"

echo ""
echo "========================================"
echo "🧹 Limpando projeto..."
echo "========================================"
echo ""
flutter clean

echo ""
echo "========================================"
echo "📦 Instalando dependências..."
echo "========================================"
echo ""
flutter pub get

echo ""
echo "========================================"
echo "🤖 Gerando build Android (App Bundle)..."
echo "========================================"
echo ""
flutter build appbundle --release --dart-define=PEXELS_API_KEY=$PEXELS_API_KEY

echo ""
echo "========================================"
echo "🍎 Gerando build iOS..."
echo "========================================"
echo ""
flutter build ios --release --dart-define=PEXELS_API_KEY=$PEXELS_API_KEY

echo ""
echo "========================================"
echo "🚀 Abrindo Xcode..."
echo "========================================"
echo ""
open ios/Runner.xcworkspace
