@echo off
setlocal

call "%USERPROFILE%\miniconda3\Scripts\activate.bat" geocampo
cd /d C:\Users\geral\Desktop\MapsG
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8001
