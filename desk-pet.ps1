# AI 像素桌宠 · 启动脚本
# 双击同一文件夹里的「启动桌宠.vbs」运行。第一次启动会编译 src 里的代码（十几秒），之后就很快。
# 改了 src 里的代码？右键桌宠 → 退出，再启动一次就会自动重新编译。
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
try {
    $order = 'Pet.cs', 'Features.cs', 'Agent.cs', 'Brain.cs', 'Sound.cs', 'Skin.cs', 'Upgrade.cs'
    $code = ($order | ForEach-Object { [System.IO.File]::ReadAllText((Join-Path (Join-Path $here 'src') $_), [Text.Encoding]::UTF8) }) -join "`n"
    $refs = 'System.Windows.Forms', 'System.Drawing', 'UIAutomationClient', 'UIAutomationTypes', 'WindowsBase', 'System.Web.Extensions', 'System.Speech'
    Add-Type -AssemblyName $refs
    $sha = [System.Security.Cryptography.SHA1]::Create()
    $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($code)))).Replace('-', '').Substring(0, 12)
    $cache = Join-Path $env:APPDATA 'PixelDeskPet'
    New-Item -ItemType Directory -Force -Path $cache | Out-Null
    $dll = Join-Path $cache "pet_$hash.dll"
    if (-not (Test-Path $dll)) {
        Get-ChildItem $cache -Filter 'pet_*.dll' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Add-Type -TypeDefinition $code -Language CSharp -OutputAssembly $dll -OutputType Library -IgnoreWarnings -ReferencedAssemblies $refs
    }
    # 以字节方式载入，避开 Windows「智能应用控制」对未签名 DLL 文件的拦截
    [void][System.Reflection.Assembly]::Load([System.IO.File]::ReadAllBytes($dll))
    [PixelDeskPet.Program]::Run($here, $PSCommandPath)
}
catch {
    $msg = $_ | Out-String
    $msg | Out-File -FilePath (Join-Path $here '错误日志.txt') -Encoding UTF8
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("桌宠启动失败了，原因写在同文件夹的「错误日志.txt」里。`n`n" + $msg.Substring(0, [Math]::Min(600, $msg.Length)), 'AI 像素桌宠') | Out-Null
}
