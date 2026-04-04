@echo off
echo ======================================================================
echo Starting Vehicle Troubleshooting Chatbot Server
echo ======================================================================
echo.

REM Set Gemini API Key
set GEMINI_API_KEY=AIzaSyDfh94Up4g4-APc8cOSN_jb39AV_3pswks

echo API Key: Set
echo Model: gemini-2.5-flash
echo.
echo Starting server on http://localhost:8000
echo API Documentation: http://localhost:8000/docs
echo.
echo ======================================================================
echo.

REM Start the API server
python api_server.py

pause
