@echo off
setlocal
cd %~dp0

echo Installing Bundler...
call gem install bundler

echo Running Bundler install...
call bundle install

echo Installing Node.js modules
call npm install

echo.
echo Done.
pause
