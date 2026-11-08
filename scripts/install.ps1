$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:LOCALAPPDATA 'mdv'
$zip = Join-Path $env:TEMP 'mdv.zip'
New-Item -ItemType Directory -Force $dir | Out-Null
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
Invoke-WebRequest "https://github.com/Satheeshsk369/mdv/releases/latest/download/mdv-windows-$arch.zip" -OutFile $zip
Expand-Archive $zip $dir -Force
Remove-Item $zip
$path = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($path -split ';') -notcontains $dir) {
    [Environment]::SetEnvironmentVariable('Path', "$path;$dir", 'User')
    Write-Host "Added $dir to PATH; open a new terminal to use mdv"
}
Write-Host "mdv installed to $dir\mdv.exe"
