[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Output 'Test content preflight passed'
& "$env:SystemRoot\System32\cmd.exe" /c exit 0
