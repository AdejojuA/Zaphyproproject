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
$packageJson = Get-Content -LiteralPath (Join-Path $projectRoot "package.json") -Raw | ConvertFrom-Json
$appVersion = [string]$packageJson.version
$iconPath = Join-Path $projectRoot "assets\icon.ico"
$hasIcon = Test-Path -LiteralPath $iconPath

if ([string]::IsNullOrWhiteSpace($appVersion)) {
  $appVersion = "1.0.0"
}

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

function New-ZahpyShortcut($shortcutPath, $targetPath, $workingDirectory, $iconPath) {
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = $targetPath
  $shortcut.WorkingDirectory = $workingDirectory
  if ($iconPath -and (Test-Path -LiteralPath $iconPath)) {
    $shortcut.IconLocation = $iconPath
  } else {
    $shortcut.IconLocation = $targetPath
  }
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
$shortcutIcon = Join-Path $installRoot "resources\assets\icon.ico"
$displayIcon = $appExe

if (Test-Path -LiteralPath $shortcutIcon) {
  $displayIcon = $shortcutIcon
}

New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
New-ZahpyShortcut $desktopShortcut $appExe $installRoot $shortcutIcon
New-ZahpyShortcut $startMenuShortcut $appExe $installRoot $shortcutIcon

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
Set-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value $displayIcon
Set-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value "wscript.exe //B //Nologo `"$uninstallVbs`""
Set-ItemProperty -Path $uninstallKey -Name "NoModify" -Value 1 -Type DWord
Set-ItemProperty -Path $uninstallKey -Name "NoRepair" -Value 1 -Type DWord

Start-Process -FilePath $appExe -WorkingDirectory $installRoot
'@

$installPs1Content = $installPs1Content.Replace(
  'Set-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value "1.0.0"',
  ('Set-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value "' + $appVersion + '"')
)

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
    private const string AppVersion = "$appVersion";
    private const string PublisherName = "Zahpy Business Pro";
    private const string SigningStatus = "Signature: Not code signed yet";

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

            using (ProgressDialog progress = new ProgressDialog())
            {
                progress.Show();
                progress.SetStatus("Preparing installer...");
                Application.DoEvents();

                string exePath = Process.GetCurrentProcess().MainModule.FileName;
                tempDir = Path.Combine(Path.GetTempPath(), "zahpy-setup-" + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(tempDir);

                string payloadPath = Path.Combine(tempDir, "payload.zip");
                string scriptPath = Path.Combine(tempDir, "install.ps1");

                progress.SetStatus("Extracting app package...");
                Application.DoEvents();
                ExtractPayload(exePath, payloadPath);

                progress.SetStatus("Preparing installation steps...");
                Application.DoEvents();
                File.WriteAllText(scriptPath, Encoding.UTF8.GetString(Convert.FromBase64String("$installScriptBase64")), Encoding.UTF8);

                ProcessStartInfo info = new ProcessStartInfo();
                info.FileName = "powershell.exe";
                info.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File " + Quote(scriptPath) + " -PayloadZip " + Quote(payloadPath);
                info.UseShellExecute = false;
                info.CreateNoWindow = true;
                info.WindowStyle = ProcessWindowStyle.Hidden;

                progress.SetStatus("Installing files and creating shortcuts...");
                Application.DoEvents();

                using (Process process = Process.Start(info))
                {
                    while (!process.WaitForExit(200))
                    {
                        Application.DoEvents();
                    }

                    if (process.ExitCode != 0)
                    {
                        throw new Exception("Installer script exited with code " + process.ExitCode + ".");
                    }
                }

                progress.SetStatus("Finishing installation...");
                Application.DoEvents();

                try
                {
                    Directory.Delete(tempDir, true);
                }
                catch
                {
                }
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
            Icon = GetInstallerIcon();
            ShowIcon = true;
            ClientSize = new Size(720, 660);
            BackColor = Color.White;
            Font = new Font("Segoe UI", 9F);

            Color navy = Color.FromArgb(15, 23, 42);
            Color blue = Color.FromArgb(37, 99, 235);
            Color slate = Color.FromArgb(71, 85, 105);
            Color light = Color.FromArgb(248, 250, 252);
            Color border = Color.FromArgb(226, 232, 240);

            Panel header = new Panel();
            header.BackColor = navy;
            header.Location = new Point(0, 0);
            header.Size = new Size(720, 116);

            Panel accent = new Panel();
            accent.BackColor = blue;
            accent.Location = new Point(0, 0);
            accent.Size = new Size(8, 116);

            Label brand = new Label();
            brand.Text = "Zahpy Business Pro";
            brand.Font = new Font("Segoe UI", 18F, FontStyle.Bold);
            brand.ForeColor = Color.White;
            brand.Location = new Point(28, 22);
            brand.Size = new Size(420, 36);

            Label title = new Label();
            title.Text = "Professional invoicing desktop setup";
            title.Font = new Font("Segoe UI", 9.5F, FontStyle.Regular);
            title.ForeColor = Color.FromArgb(203, 213, 225);
            title.Location = new Point(30, 60);
            title.Size = new Size(520, 24);

            Panel iconFrame = new Panel();
            iconFrame.BackColor = Color.White;
            iconFrame.BorderStyle = BorderStyle.FixedSingle;
            iconFrame.Location = new Point(624, 28);
            iconFrame.Size = new Size(54, 54);

            PictureBox logo = new PictureBox();
            logo.Image = GetInstallerIcon().ToBitmap();
            logo.SizeMode = PictureBoxSizeMode.CenterImage;
            logo.Location = new Point(7, 7);
            logo.Size = new Size(38, 38);
            iconFrame.Controls.Add(logo);

            header.Controls.Add(accent);
            header.Controls.Add(brand);
            header.Controls.Add(title);
            header.Controls.Add(iconFrame);

            Panel headerBorder = new Panel();
            headerBorder.BackColor = Color.FromArgb(191, 219, 254);
            headerBorder.Location = new Point(0, 116);
            headerBorder.Size = new Size(720, 2);

            Label step = new Label();
            step.Text = "Step 1 of 2";
            step.Font = new Font("Segoe UI", 8.5F, FontStyle.Bold);
            step.ForeColor = blue;
            step.Location = new Point(30, 136);
            step.Size = new Size(160, 22);

            Label subtitle = new Label();
            subtitle.Text = "Review the install details and terms before continuing.";
            subtitle.Font = new Font("Segoe UI", 11F, FontStyle.Bold);
            subtitle.ForeColor = navy;
            subtitle.Location = new Point(28, 160);
            subtitle.Size = new Size(620, 26);

            Panel trustPanel = new Panel();
            trustPanel.BackColor = light;
            trustPanel.BorderStyle = BorderStyle.FixedSingle;
            trustPanel.Location = new Point(30, 200);
            trustPanel.Size = new Size(660, 58);

            Label version = new Label();
            version.Text = "Version v" + AppVersion;
            version.Font = new Font("Segoe UI", 8.75F, FontStyle.Bold);
            version.ForeColor = navy;
            version.Location = new Point(14, 10);
            version.Size = new Size(130, 20);

            Label publisher = new Label();
            publisher.Text = "Publisher: " + PublisherName;
            publisher.Font = new Font("Segoe UI", 8.75F, FontStyle.Bold);
            publisher.ForeColor = navy;
            publisher.Location = new Point(168, 10);
            publisher.Size = new Size(210, 20);

            Label signature = new Label();
            signature.Text = SigningStatus;
            signature.Font = new Font("Segoe UI", 8.75F, FontStyle.Bold);
            signature.ForeColor = Color.FromArgb(100, 116, 139);
            signature.Location = new Point(410, 10);
            signature.Size = new Size(220, 20);

            Label privacy = new Label();
            privacy.Text = "Core records stay on this device unless you use an online link or service.";
            privacy.ForeColor = slate;
            privacy.Location = new Point(14, 31);
            privacy.Size = new Size(610, 20);

            trustPanel.Controls.Add(version);
            trustPanel.Controls.Add(publisher);
            trustPanel.Controls.Add(signature);
            trustPanel.Controls.Add(privacy);

            Label location = new Label();
            location.Text = "Install location: " + Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Programs\Zahpy Business Pro");
            location.ForeColor = slate;
            location.Location = new Point(30, 278);
            location.Size = new Size(650, 38);

            Label termsTitle = new Label();
            termsTitle.Text = "Terms and data notice";
            termsTitle.Font = new Font("Segoe UI", 9.25F, FontStyle.Bold);
            termsTitle.ForeColor = navy;
            termsTitle.Location = new Point(30, 324);
            termsTitle.Size = new Size(240, 22);

            TextBox terms = new TextBox();
            terms.Multiline = true;
            terms.ReadOnly = true;
            terms.ScrollBars = ScrollBars.Vertical;
            terms.BorderStyle = BorderStyle.FixedSingle;
            terms.BackColor = light;
            terms.ForeColor = Color.FromArgb(30, 41, 59);
            terms.Font = new Font("Segoe UI", 9.75F);
            terms.Location = new Point(30, 350);
            terms.Size = new Size(660, 198);
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
            agree.ForeColor = navy;
            agree.Location = new Point(30, 570);
            agree.Size = new Size(430, 28);

            Button cancel = new Button();
            cancel.Text = "Cancel";
            cancel.DialogResult = DialogResult.Cancel;
            cancel.FlatStyle = FlatStyle.Flat;
            cancel.UseVisualStyleBackColor = false;
            cancel.BackColor = Color.White;
            cancel.ForeColor = navy;
            cancel.FlatAppearance.BorderColor = border;
            cancel.Location = new Point(488, 614);
            cancel.Size = new Size(94, 38);

            Button install = new Button();
            install.Text = "Install";
            install.DialogResult = DialogResult.OK;
            install.Enabled = false;
            install.FlatStyle = FlatStyle.Flat;
            install.UseVisualStyleBackColor = false;
            install.BackColor = blue;
            install.ForeColor = Color.White;
            install.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
            install.FlatAppearance.BorderColor = blue;
            install.Location = new Point(596, 614);
            install.Size = new Size(94, 38);

            agree.CheckedChanged += delegate
            {
                install.Enabled = agree.Checked;
                install.BackColor = agree.Checked ? Color.FromArgb(29, 78, 216) : Color.FromArgb(148, 163, 184);
                install.FlatAppearance.BorderColor = install.BackColor;
            };

            install.BackColor = Color.FromArgb(148, 163, 184);
            install.FlatAppearance.BorderColor = install.BackColor;

            Controls.Add(header);
            Controls.Add(headerBorder);
            Controls.Add(step);
            Controls.Add(subtitle);
            Controls.Add(trustPanel);
            Controls.Add(location);
            Controls.Add(termsTitle);
            Controls.Add(terms);
            Controls.Add(agree);
            Controls.Add(cancel);
            Controls.Add(install);

            AcceptButton = install;
            CancelButton = cancel;
        }
    }

    private sealed class ProgressDialog : Form
    {
        private readonly Label statusLabel;
        private readonly ProgressBar progressBar;

        public ProgressDialog()
        {
            Text = "Installing Zahpy Business Pro";
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            ControlBox = false;
            Icon = GetInstallerIcon();
            ShowIcon = true;
            ClientSize = new Size(520, 260);
            BackColor = Color.White;
            Font = new Font("Segoe UI", 9F);

            Color navy = Color.FromArgb(15, 23, 42);
            Color blue = Color.FromArgb(37, 99, 235);
            Color slate = Color.FromArgb(71, 85, 105);

            Panel header = new Panel();
            header.BackColor = navy;
            header.Location = new Point(0, 0);
            header.Size = new Size(520, 92);

            Panel accent = new Panel();
            accent.BackColor = blue;
            accent.Location = new Point(0, 0);
            accent.Size = new Size(8, 92);

            PictureBox logo = new PictureBox();
            logo.Image = GetInstallerIcon().ToBitmap();
            logo.SizeMode = PictureBoxSizeMode.CenterImage;
            logo.BackColor = Color.White;
            logo.Location = new Point(28, 22);
            logo.Size = new Size(42, 42);

            Label title = new Label();
            title.Text = "Installing Zahpy Business Pro";
            title.Font = new Font("Segoe UI", 15F, FontStyle.Bold);
            title.ForeColor = Color.White;
            title.Location = new Point(86, 18);
            title.Size = new Size(390, 30);

            Label subtitle = new Label();
            subtitle.Text = "Step 2 of 2 - Please wait while setup finishes.";
            subtitle.ForeColor = Color.FromArgb(203, 213, 225);
            subtitle.Location = new Point(88, 51);
            subtitle.Size = new Size(390, 20);

            header.Controls.Add(accent);
            header.Controls.Add(logo);
            header.Controls.Add(title);
            header.Controls.Add(subtitle);

            statusLabel = new Label();
            statusLabel.Text = "Preparing installer...";
            statusLabel.ForeColor = slate;
            statusLabel.Location = new Point(30, 124);
            statusLabel.Size = new Size(460, 24);

            progressBar = new ProgressBar();
            progressBar.Style = ProgressBarStyle.Marquee;
            progressBar.MarqueeAnimationSpeed = 28;
            progressBar.Location = new Point(30, 164);
            progressBar.Size = new Size(460, 18);

            Label note = new Label();
            note.Text = "This may take a moment on the first install.";
            note.ForeColor = Color.FromArgb(100, 116, 139);
            note.Location = new Point(30, 196);
            note.Size = new Size(460, 22);

            Controls.Add(header);
            Controls.Add(statusLabel);
            Controls.Add(progressBar);
            Controls.Add(note);
        }

        public void SetStatus(string message)
        {
            statusLabel.Text = message;
            statusLabel.Refresh();
            progressBar.Refresh();
        }
    }

    private static Icon GetInstallerIcon()
    {
        try
        {
            Icon icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            if (icon != null)
            {
                return icon;
            }
        }
        catch
        {
        }

        return SystemIcons.Application;
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

$compileArgs = @(
  "/nologo",
  "/target:winexe",
  "/platform:anycpu",
  "/reference:System.Windows.Forms.dll",
  "/reference:System.Drawing.dll",
  "/out:$stubExe",
  $sourcePath
)

if ($hasIcon) {
  $compileArgs += "/win32icon:$iconPath"
}

& $csc @compileArgs

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
