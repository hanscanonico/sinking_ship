# ./start from PowerShell: the same four steps as the sh script beside it.
# Arguments go to make run: ./start FAST=1
Set-Location $PSScriptRoot
git pull --ff-only; if ($LASTEXITCODE) { exit $LASTEXITCODE }
make import; if ($LASTEXITCODE) { exit $LASTEXITCODE }
make native; if ($LASTEXITCODE) { exit $LASTEXITCODE }
make run @args; exit $LASTEXITCODE
