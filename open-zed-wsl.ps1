$zedExecutable = Join-Path $env:LOCALAPPDATA 'Programs\Zed\bin\Zed.exe'
if (!(Test-Path -LiteralPath $zedExecutable)) { throw 'Zed executable was not found.' }
$projectRoot = $PSScriptRoot.Replace('\', '/')
$resolvedPath = wsl -d Ubuntu-26.04 --exec wslpath -a -u $projectRoot
if ($LASTEXITCODE -ne 0) { throw 'Could not resolve the project path in WSL.' }
$linuxPath = $resolvedPath.Trim()
& $zedExecutable --wsl Ubuntu-26.04 --new $linuxPath "$linuxPath/app/models/project.rb"
