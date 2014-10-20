@echo off
setlocal
cd %~dp0
call gem install bundler
call bundle install
call npm install
copy Nuget.exe C:\Ruby193\bin
pause
