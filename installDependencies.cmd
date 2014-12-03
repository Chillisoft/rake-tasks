@echo off
setlocal
cd %~dp0

echo Installing Bundler...
call gem install bundler

echo Ensuring that gem Bundler will work properly with https
call gem update --system

echo Running Bundler install...
call bundle install

echo Installing Node.js modules
call npm install

echo.
echo Done.
pause
