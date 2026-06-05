$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$outputRoot = Join-Path $projectRoot "..\..\outputs"
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$outputRoot = (Resolve-Path $outputRoot).Path

$appDir = Join-Path $outputRoot "win-unpacked"
$appExe = Join-Path $appDir "Zahpy Business Pro.exe"
$setupExe = Join-Path $outputRoot "ZahpyBusinessPro-Setup.exe"
$workDir = Join-Path $outputRoot "installer-work"
$payloadZip = Join-Path $workDir "payload.zip"
$sourcePath = Join-Path $workDir "ZahpySetup.cs"
$stubExe = Join-Path $workDir "ZahpySetupStub.exe"
$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (!(Test-Path -LiteralPath $appExe)) {
  throw "Built app was not found: $appExe"
}

if (!(Test-Path -LiteralPath $csc)) {
  $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe"
}

if (!(Test-Path -LiteralPath $csc)) {
  throw "C# compiler was not found."
}

if (Test-Path -LiteralPath $workDir) {
  $resolvedWorkDir = (Resolve-Path $workDir).Path
  if (!$resolvedWorkDir.StartsWith($outputRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove installer work directory outside output root: $resolvedWorkDir"
  }
  Remove-Item -LiteralPath $workDir -Recurse -Force
}

New-Item -ItemType Directory -Path $workDir -Force | Out-Null

if (Test-Path -LiteralPath $setupExe) {
  Remove-Item -LiteralPath $setupExe -Force
}

Compress-Archive -Path (Join-Path $appDir "*") -DestinationPath $payloadZip -Force

$installPs1Content = @'
param(
  [Parameter(Mandatory=$true)]
  [string]$PayloadZip
)

$ErrorActionPreference = "Stop"

$installRoot = Join-Path $env:LOCALAPPDATA "Programs\Zahpy Business Pro"
$parentDir = Split-Path $installRoot -Parent
$tempDir = Join-Path $env:TEMP ("zahpy-install-" + [guid]::NewGuid().ToString("N"))

function New-ZahpyShortcut($shortcutPath, $targetPath, $workingDirectory) {
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = $targetPath
  $shortcut.WorkingDirectory = $workingDirectory
  $shortcut.IconLocation = $targetPath
  $shortcut.Save()
}

New-Item -ItemType Directory -Path $parentDir -Force | Out-Null

if (Test-Path -LiteralPath $installRoot) {
  Remove-Item -LiteralPath $installRoot -Recurse -Force
}

Expand-Archive -LiteralPath $PayloadZip -DestinationPath $tempDir -Force
Move-Item -LiteralPath $tempDir -Destination $installRoot

$appExe = Join-Path $installRoot "Zahpy Business Pro.exe"
$desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Zahpy Business Pro.lnk"
$startMenuDir = Join-Path ([Environment]::GetFolderPath("Programs")) "Zahpy Business Pro"
$startMenuShortcut = Join-Path $startMenuDir "Zahpy Business Pro.lnk"
$uninstallCmd = Join-Path $installRoot "Uninstall Zahpy Business Pro.cmd"
$uninstallPs1 = Join-Path $installRoot "uninstall.ps1"

New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
New-ZahpyShortcut $desktopShortcut $appExe $installRoot
New-ZahpyShortcut $startMenuShortcut $appExe $installRoot

$uninstallPs1Content = @"
`$ErrorActionPreference = "Stop"
`$installRoot = "$($installRoot.Replace('"','`"'))"
`$desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Zahpy Business Pro.lnk"
`$startMenuDir = Join-Path ([Environment]::GetFolderPath("Programs")) "Zahpy Business Pro"
if (Test-Path -LiteralPath `$desktopShortcut) { Remove-Item -LiteralPath `$desktopShortcut -Force }
if (Test-Path -LiteralPath `$startMenuDir) { Remove-Item -LiteralPath `$startMenuDir -Recurse -Force }
if (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ZahpyBusinessPro") {
  Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ZahpyBusinessPro" -Recurse -Force
}
Start-Sleep -Milliseconds 300
if (Test-Path -LiteralPath `$installRoot) { Remove-Item -LiteralPath `$installRoot -Recurse -Force }
"@

Set-Content -LiteralPath $uninstallPs1 -Value $uninstallPs1Content -Encoding UTF8
Set-Content -LiteralPath $uninstallCmd -Value '@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
' -Encoding ASCII

$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ZahpyBusinessPro"
New-Item -Path $uninstallKey -Force | Out-Null
Set-ItemProperty -Path $uninstallKey -Name "DisplayName" -Value "Zahpy Business Pro"
Set-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value "1.0.0"
Set-ItemProperty -Path $uninstallKey -Name "Publisher" -Value "Zahpy Business Pro"
Set-ItemProperty -Path $uninstallKey -Name "InstallLocation" -Value $installRoot
Set-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value $appExe
Set-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value "`"$uninstallCmd`""
Set-ItemProperty -Path $uninstallKey -Name "NoModify" -Value 1 -Type DWord
Set-ItemProperty -Path $uninstallKey -Name "NoRepair" -Value 1 -Type DWord

Start-Process -FilePath $appExe -WorkingDirectory $installRoot
'@

$installScriptBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($installPs1Content))

$csharp = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows.Forms;

public static class ZahpySetup
{
    private static readonly byte[] Marker = Encoding.ASCII.GetBytes("ZAHPY_PAYLOAD_V1");

    [STAThread]
    public static int Main()
    {
        string tempDir = null;

        try
        {
            string exePath = Process.GetCurrentProcess().MainModule.FileName;
            tempDir = Path.Combine(Path.GetTempPath(), "zahpy-setup-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);

            string payloadPath = Path.Combine(tempDir, "payload.zip");
            string scriptPath = Path.Combine(tempDir, "install.ps1");

            ExtractPayload(exePath, payloadPath);
            File.WriteAllText(scriptPath, Encoding.UTF8.GetString(Convert.FromBase64String("$installScriptBase64")), Encoding.UTF8);

            ProcessStartInfo info = new ProcessStartInfo();
            info.FileName = "powershell.exe";
            info.Arguments = "-NoProfile -ExecutionPolicy Bypass -File " + Quote(scriptPath) + " -PayloadZip " + Quote(payloadPath);
            info.UseShellExecute = false;
            info.CreateNoWindow = false;

            using (Process process = Process.Start(info))
            {
                process.WaitForExit();
                if (process.ExitCode != 0)
                {
                    throw new Exception("Installer script exited with code " + process.ExitCode + ".");
                }
            }

            try
            {
                Directory.Delete(tempDir, true);
            }
            catch
            {
            }

            return 0;
        }
        catch (Exception error)
        {
            MessageBox.Show("Zahpy Business Pro could not be installed.\n\n" + error.Message, "Zahpy Business Pro Setup", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    private static void ExtractPayload(string exePath, string outputPath)
    {
        using (FileStream input = File.OpenRead(exePath))
        {
            if (input.Length < Marker.Length + 8)
            {
                throw new Exception("Installer payload is missing.");
            }

            input.Seek(-8, SeekOrigin.End);
            byte[] lengthBytes = new byte[8];
            ReadExact(input, lengthBytes, lengthBytes.Length);
            long payloadLength = BitConverter.ToInt64(lengthBytes, 0);

            input.Seek(-(8 + Marker.Length), SeekOrigin.End);
            byte[] markerBytes = new byte[Marker.Length];
            ReadExact(input, markerBytes, markerBytes.Length);

            for (int index = 0; index < Marker.Length; index++)
            {
                if (markerBytes[index] != Marker[index])
                {
                    throw new Exception("Installer payload marker is invalid.");
                }
            }

            long payloadStart = input.Length - 8 - Marker.Length - payloadLength;
            if (payloadLength <= 0 || payloadStart < 0)
            {
                throw new Exception("Installer payload length is invalid.");
            }

            input.Seek(payloadStart, SeekOrigin.Begin);

            using (FileStream output = File.Create(outputPath))
            {
                byte[] buffer = new byte[1024 * 1024];
                long remaining = payloadLength;

                while (remaining > 0)
                {
                    int toRead = (int)Math.Min(buffer.Length, remaining);
                    int read = input.Read(buffer, 0, toRead);
                    if (read <= 0)
                    {
                        throw new EndOfStreamException("Installer payload ended unexpectedly.");
                    }

                    output.Write(buffer, 0, read);
                    remaining -= read;
                }
            }
        }
    }

    private static void ReadExact(Stream stream, byte[] buffer, int count)
    {
        int offset = 0;
        while (offset < count)
        {
            int read = stream.Read(buffer, offset, count - offset);
            if (read <= 0)
            {
                throw new EndOfStreamException();
            }
            offset += read;
        }
    }

    private static string Quote(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }
}
"@

Set-Content -LiteralPath $sourcePath -Value $csharp -Encoding UTF8

& $csc /nologo /target:winexe /platform:anycpu /reference:System.Windows.Forms.dll /out:$stubExe $sourcePath

if (!(Test-Path -LiteralPath $stubExe)) {
  throw "Installer stub was not compiled: $stubExe"
}

Copy-Item -LiteralPath $stubExe -Destination $setupExe -Force

$marker = [Text.Encoding]::ASCII.GetBytes("ZAHPY_PAYLOAD_V1")
$payloadLength = (Get-Item -LiteralPath $payloadZip).Length
$lengthBytes = [BitConverter]::GetBytes([Int64]$payloadLength)
$outStream = [IO.File]::Open($setupExe, [IO.FileMode]::Append, [IO.FileAccess]::Write)

try {
  $inStream = [IO.File]::OpenRead($payloadZip)
  try {
    $inStream.CopyTo($outStream)
  } finally {
    $inStream.Dispose()
  }

  $outStream.Write($marker, 0, $marker.Length)
  $outStream.Write($lengthBytes, 0, $lengthBytes.Length)
} finally {
  $outStream.Dispose()
}

if (!(Test-Path -LiteralPath $setupExe)) {
  throw "Installer was not created: $setupExe"
}

Write-Host "Installer written to $setupExe"
