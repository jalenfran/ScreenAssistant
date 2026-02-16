#!/bin/bash

# Load .env if it exists
if [ -f ".env" ]; then
    export $(cat .env | xargs)
fi

# Ensure we have an API Key
if [ -z "$GEMINI_API_KEY" ]; then
    echo "Please set GEMINI_API_KEY environment variable."
    read -p "Enter your Google Gemini API Key: " GEMINI_API_KEY
    export GEMINI_API_KEY
fi

# Build
swift build

# Run
./.build/debug/ScreenAssistant
