#!/bin/bash

# Load .env if it exists
if [ -f ".env" ]; then
    export $(cat .env | xargs)
fi

if [ -z "$GEMINI_API_KEY" ]; then
    echo "GEMINI_API_KEY is not set."
    exit 1
fi

curl "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY"
