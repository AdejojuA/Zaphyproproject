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
$uninstallVbs = Join-Path $installRoot "uninstall.vbs"

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
powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
' -Encoding ASCII
Set-Content -LiteralPath $uninstallVbs -Value 'Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptPath = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "uninstall.ps1")
shell.Run "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File " & Chr(34) & scriptPath & Chr(34), 0, True
' -Encoding ASCII

$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ZahpyBusinessPro"
New-Item -Path $uninstallKey -Force | Out-Null
Set-ItemProperty -Path $uninstallKey -Name "DisplayName" -Value "Zahpy Business Pro"
Set-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value "1.0.0"
Set-ItemProperty -Path $uninstallKey -Name "Publisher" -Value "Zahpy Business Pro"
Set-ItemProperty -Path $uninstallKey -Name "InstallLocation" -Value $installRoot
Set-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value $appExe
Set-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value "wscript.exe //B //Nologo `"$uninstallVbs`""
Set-ItemProperty -Path $uninstallKey -Name "NoModify" -Value 1 -Type DWord
Set-ItemProperty -Path $uninstallKey -Name "NoRepair" -Value 1 -Type DWord

Start-Process -FilePath $appExe -WorkingDirectory $installRoot
'@

$installScriptBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($installPs1Content))

$csharp = @"
using System;
using System.Diagnostics;
using System.Drawing;
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
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            if (!ShowInstallDialog())
            {
                return 0;
            }

            string exePath = Process.GetCurrentProcess().MainModule.FileName;
            tempDir = Path.Combine(Path.GetTempPath(), "zahpy-setup-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);

            string payloadPath = Path.Combine(tempDir, "payload.zip");
            string scriptPath = Path.Combine(tempDir, "install.ps1");

            ExtractPayload(exePath, payloadPath);
            File.WriteAllText(scriptPath, Encoding.UTF8.GetString(Convert.FromBase64String("$installScriptBase64")), Encoding.UTF8);

            ProcessStartInfo info = new ProcessStartInfo();
            info.FileName = "powershell.exe";
            info.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File " + Quote(scriptPath) + " -PayloadZip " + Quote(payloadPath);
            info.UseShellExecute = false;
            info.CreateNoWindow = true;
            info.WindowStyle = ProcessWindowStyle.Hidden;

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

    private static bool ShowInstallDialog()
    {
        using (InstallDialog dialog = new InstallDialog())
        {
            return dialog.ShowDialog() == DialogResult.OK;
        }
    }

    private sealed class InstallDialog : Form
    {
        public InstallDialog()
        {
            Text = "Zahpy Business Pro Setup";
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            ShowIcon = true;
            ClientSize = new Size(640, 540);
            BackColor = Color.White;
            Font = new Font("Segoe UI", 9F);

            Label title = new Label();
            title.Text = "Install Zahpy Business Pro";
            title.Font = new Font("Segoe UI", 17F, FontStyle.Bold);
            title.ForeColor = Color.FromArgb(15, 23, 42);
            title.Location = new Point(24, 22);
            title.Size = new Size(590, 34);

            Label subtitle = new Label();
            subtitle.Text = "Review the install details and terms before continuing.";
            subtitle.ForeColor = Color.FromArgb(71, 85, 105);
            subtitle.Location = new Point(26, 62);
            subtitle.Size = new Size(590, 24);

            Label location = new Label();
            location.Text = "Install location: " + Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Programs\Zahpy Business Pro");
            location.ForeColor = Color.FromArgb(51, 65, 85);
            location.Location = new Point(26, 100);
            location.Size = new Size(590, 24);

            TextBox terms = new TextBox();
            terms.Multiline = true;
            terms.ReadOnly = true;
            terms.ScrollBars = ScrollBars.Vertical;
            terms.BorderStyle = BorderStyle.FixedSingle;
            terms.Location = new Point(26, 134);
            terms.Size = new Size(588, 270);
            terms.Text =
                "Zahpy Business Pro Setup" + Environment.NewLine + Environment.NewLine +
                "This installer will copy Zahpy Business Pro to the current user's local Programs folder, create a desktop shortcut, create a Start Menu shortcut, register an uninstall entry, and launch the app after installation." + Environment.NewLine + Environment.NewLine +
                "Local data and backups:" + Environment.NewLine +
                "- Zahpy Business Pro stores invoices, clients, catalog items, payments, and settings on this device." + Environment.NewLine +
                "- The app does not automatically upload or sync your business records to a Zahpy cloud server." + Environment.NewLine +
                "- Use the app's Backup button regularly and keep copies of important business records." + Environment.NewLine + Environment.NewLine +
                "Accuracy and responsibility:" + Environment.NewLine +
                "- Zahpy Business Pro is a document tool, not legal, tax, accounting, or financial advice." + Environment.NewLine +
                "- You are responsible for checking invoice totals, tax rates, payment terms, business details, and client details before sending documents." + Environment.NewLine + Environment.NewLine +
                "Online features:" + Environment.NewLine +
                "- The core app can run locally. Update checks, GitHub downloads, email links, PayPal links, Stripe links, and other third-party services require internet access." + Environment.NewLine +
                "- Third-party services are governed by their own terms, fees, privacy policies, and account requirements." + Environment.NewLine + Environment.NewLine +
                "Security:" + Environment.NewLine +
                "- If you enable the optional PIN lock, forgotten PINs cannot be recovered.";

            CheckBox agree = new CheckBox();
            agree.Text = "I have read and agree to these terms.";
            agree.ForeColor = Color.FromArgb(30, 41, 59);
            agree.Location = new Point(26, 418);
            agree.Size = new Size(420, 26);

            Button cancel = new Button();
            cancel.Text = "Cancel";
            cancel.DialogResult = DialogResult.Cancel;
            cancel.Location = new Point(410, 470);
            cancel.Size = new Size(92, 34);

            Button install = new Button();
            install.Text = "Install";
            install.DialogResult = DialogResult.OK;
            install.Enabled = false;
            install.Location = new Point(520, 470);
            install.Size = new Size(92, 34);

            agree.CheckedChanged += delegate
            {
                install.Enabled = agree.Checked;
            };

            Controls.Add(title);
            Controls.Add(subtitle);
            Controls.Add(location);
            Controls.Add(terms);
            Controls.Add(agree);
            Controls.Add(cancel);
            Controls.Add(install);

            AcceptButton = install;
            CancelButton = cancel;
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

& $csc /nologo /target:winexe /platform:anycpu /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /out:$stubExe $sourcePath

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
