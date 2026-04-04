#!/bin/bash

# RoadResQ Flutter App Setup Script
# This script helps you set up and run the Flutter app quickly

echo "🚗 RoadResQ Flutter App Setup"
echo "=============================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Flutter is installed
echo "📋 Checking prerequisites..."
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed${NC}"
    echo "Please install Flutter from: https://flutter.dev/docs/get-started/install"
    exit 1
else
    echo -e "${GREEN}✅ Flutter is installed${NC}"
    flutter --version
fi

echo ""

# Check if dependencies are installed
echo "📦 Installing dependencies..."
flutter pub get

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Dependencies installed successfully${NC}"
else
    echo -e "${RED}❌ Failed to install dependencies${NC}"
    exit 1
fi

echo ""

# Get local IP address
echo "🌐 Finding your local IP address..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    LOCAL_IP=$(hostname -I | awk '{print $1}')
else
    LOCAL_IP="Unable to detect"
fi

echo -e "${GREEN}Your local IP: $LOCAL_IP${NC}"
echo ""

# Check if API server is running
echo "🔍 Checking if API server is running..."
if curl -s http://localhost:8007/ > /dev/null 2>&1; then
    echo -e "${GREEN}✅ API server is running on http://localhost:8007${NC}"
    SERVER_RUNNING=true
else
    echo -e "${YELLOW}⚠️  API server is NOT running${NC}"
    echo "Please start it in another terminal:"
    echo "  cd .. && python main.py"
    SERVER_RUNNING=false
fi

echo ""

# Device selection
echo "📱 Available devices:"
flutter devices

echo ""
echo "=============================="
echo "🎯 Setup Summary"
echo "=============================="
echo ""
echo "API Server Status:"
if [ "$SERVER_RUNNING" = true ]; then
    echo -e "  ${GREEN}✅ Running on http://localhost:8007${NC}"
else
    echo -e "  ${RED}❌ Not running - start it first!${NC}"
fi

echo ""
echo "Configure API URL in lib/services/damage_detection_service.dart:"
echo "  • iOS Simulator:    http://localhost:8007"
echo "  • Android Emulator: http://192.168.8.162:8007"
echo "  • Physical Device:  http://$LOCAL_IP:8007"

echo ""
echo "=============================="
echo "🚀 Ready to Run!"
echo "=============================="
echo ""
echo "To run the app, use:"
echo "  flutter run"
echo ""
echo "Or for specific device:"
echo "  flutter run -d <device-id>"
echo ""

# Ask if user wants to run now
read -p "Do you want to run the app now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Starting Flutter app..."
    flutter run
fi
