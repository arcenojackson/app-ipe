#!/bin/bash
set -e

PEXELS_API_KEY="lPOKBczwM78ipvUUO9zwbU2JTCevDxH23edZ8dIa8kYg6GUVVGit1eYn"

echo "🧹 Limpando projeto..."
flutter clean

echo "📦 Instalando dependências..."
flutter pub get

echo "🤖 Gerando build Android (App Bundle)..."
flutter build appbundle --release --dart-define=PEXELS_API_KEY=$PEXELS_API_KEY

echo "🍎 Gerando build iOS..."
flutter build ios --release --dart-define=PEXELS_API_KEY=$PEXELS_API_KEY

echo "🚀 Abrindo Xcode..."
open ios/Runner.xcworkspace
