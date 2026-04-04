#!/bin/bash

# Vehicle Chatbot Server Startup Script for macOS/Linux
# Usage: ./run_server.sh

echo "======================================================================"
echo "Starting Vehicle Troubleshooting Chatbot Server"
echo "======================================================================"
echo ""

# Set the Gemini API key
export GEMINI_API_KEY="AIzaSyDfh94Up4g4-APc8cOSN_jb39AV_3pswks"

# Optional: Enable Firebase (set to 1 to enable)
export ENABLE_FIREBASE=0

echo "Configuration:"
echo "  - API Key: Set"
echo "  - Firebase: Disabled"
echo "  - Port: 8000"
echo ""

# Check if virtual environment exists
if [ -d "venv" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
else
    echo "⚠️  Warning: Virtual environment not found. Using system Python."
fi

echo ""
echo "Starting Uvicorn server..."
echo ""
echo "======================================================================="
echo "Server will be available at: http://localhost:8000"
echo "API Documentation: http://localhost:8000/docs"
echo "======================================================================="
echo ""
echo "Press CTRL+C to stop the server"
echo ""

# Start the server
python -m uvicorn src.api.api_server:app --reload --host 0.0.0.0 --port 8000
