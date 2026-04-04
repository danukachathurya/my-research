@echo off
echo ======================================================================
echo Starting Vehicle Troubleshooting Chatbot Server (TESTING MODE)
echo ======================================================================
echo.
echo This version runs WITHOUT Firebase - perfect for testing!
echo.
echo What works:
echo   - Gemini AI chatbot responses
echo   - Knowledge base search (250+ vehicle issues)
echo   - Fallback diagnostic questions
echo   - Warning light detection
echo   - Text translation
echo.
echo What does NOT work:
echo   - Saving conversation history (requires Firebase)
echo   - Storing uploaded images permanently (requires Firebase)
echo.
echo ======================================================================
echo.

REM Set Gemini API Key
set GEMINI_API_KEY=AIzaSyDfh94Up4g4-APc8cOSN_jb39AV_3pswks

REM Disable Firebase (testing mode)
set ENABLE_FIREBASE=0

echo API Key: Set
echo Model: gemini-2.5-flash
echo Firebase: DISABLED (testing mode - conversations NOT saved)
echo.
echo Starting server on http://localhost:8001
echo API Documentation: http://localhost:8001/docs
echo.
echo ======================================================================
echo.

REM Start the API server from new folder structure
python -m uvicorn src.api.api_server:app --host 0.0.0.0 --port 8001 --reload

pause
