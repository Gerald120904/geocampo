$ErrorActionPreference = "Stop"

$conda = Join-Path $env:USERPROFILE "miniconda3\Scripts\conda.exe"
if (-not (Test-Path $conda)) {
    throw "No se encontro conda en $conda"
}

Set-Location $PSScriptRoot
& $conda run -n geocampo python -m uvicorn app.main:app --host 127.0.0.1 --port 8001
