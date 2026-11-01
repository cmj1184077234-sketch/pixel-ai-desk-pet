# 叮叮 · 一键安装 / 更新（Windows）
# 用法：在 PowerShell 里运行
#   irm https://raw.githubusercontent.com/cmj1184077234-sketch/pixel-ai-desk-pet/main/install.ps1 | iex
$ErrorActionPreference = 'Stop'
$repo = 'cmj1184077234-sketch/pixel-ai-desk-pet'
$dest = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'DingDing'
Write-Host '正在下载叮叮……'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tmp = Join-Path $env:TEMP ('dingding_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp 'dingding.zip'
Invoke-WebRequest -UseBasicParsing "https://github.com/$repo/archive/refs/heads/main.zip" -OutFile $zip
Expand-Archive $zip -DestinationPath $tmp -Force
$src = Join-Path $tmp 'pixel-ai-desk-pet-main'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
# 已经装过的话只更新程序，你的 config.txt、日记、记忆都会保留
robocopy $src $dest /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw '复制文件失败了' }
Get-ChildItem $dest -Recurse -File | Unblock-File
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
$vbs = Join-Path $dest '启动桌宠.vbs'
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) '叮叮.lnk'))
$lnk.TargetPath = 'wscript.exe'; $lnk.Arguments = '"' + $vbs + '"'; $lnk.WorkingDirectory = $dest; $lnk.Save()
Start-Process wscript.exe -ArgumentList ('"' + $vbs + '"')
Write-Host ''
Write-Host "装好了！装在：$dest"
Write-Host '叮叮马上就会出现在任务栏上方（第一次要等十几秒）。以后双击桌面上的「叮叮」就能打开。'
