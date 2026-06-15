$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$outputRoot = Join-Path $projectRoot "..\..\outputs"
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$outputRoot = (Resolve-Path $outputRoot).Path

$appDir = Join-Path $outputRoot "win-unpacked"
$appExe = Join-Path $appDir "Zahpy Business Pro.exe"
$portableExe = Join-Path $outputRoot "ZahpyBusinessPro-Standalone.exe"
$workDir = Join-Path $outputRoot "portable-work"
$payloadZip = Join-Path $workDir "payload.zip"
$sourcePath = Join-Path $workDir "ZahpyPortable.cs"
$stubExe = Join-Path $workDir "ZahpyPortableStub.exe"
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
    throw "Refusing to remove portable work directory outside output root: $resolvedWorkDir"
  }
  Remove-Item -LiteralPath $workDir -Recurse -Force
}

New-Item -ItemType Directory -Path $workDir -Force | Out-Null

if (Test-Path -LiteralPath $portableExe) {
  Remove-Item -LiteralPath $portableExe -Force
}

Compress-Archive -Path (Join-Path $appDir "*") -DestinationPath $payloadZip -Force

$csharp = @"
using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Text;
using System.Windows.Forms;

public static class ZahpyPortable
{
    private static readonly byte[] Marker = Encoding.ASCII.GetBytes("ZAHPY_PORTABLE_V1");
    private const string AppVersion = "$appVersion";

    [STAThread]
    public static int Main()
    {
        try
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            string exePath = Process.GetCurrentProcess().MainModule.FileName;
            long payloadLength = ReadPayloadLength(exePath);
            string cacheRoot = Path.Combine(Path.GetTempPath(), "ZahpyBusinessProPortable");
            string cacheKey = "v" + AppVersion + "-" + payloadLength.ToString();
            string extractRoot = Path.Combine(cacheRoot, cacheKey);
            string appExe = Path.Combine(extractRoot, "Zahpy Business Pro.exe");

            Directory.CreateDirectory(cacheRoot);

            if (!File.Exists(appExe))
            {
                string stagingRoot = Path.Combine(cacheRoot, "extract-" + Guid.NewGuid().ToString("N"));
                string payloadPath = Path.Combine(cacheRoot, "payload-" + Guid.NewGuid().ToString("N") + ".zip");

                try
                {
                    ExtractPayload(exePath, payloadPath);
                    Directory.CreateDirectory(stagingRoot);
                    ZipFile.ExtractToDirectory(payloadPath, stagingRoot);

                    if (Directory.Exists(extractRoot))
                    {
                        Directory.Delete(extractRoot, true);
                    }

                    Directory.Move(stagingRoot, extractRoot);
                }
                finally
                {
                    try
                    {
                        if (File.Exists(payloadPath))
                        {
                            File.Delete(payloadPath);
                        }

                        if (Directory.Exists(stagingRoot))
                        {
                            Directory.Delete(stagingRoot, true);
                        }
                    }
                    catch
                    {
                    }
                }
            }

            if (!File.Exists(appExe))
            {
                throw new FileNotFoundException("The portable app could not be prepared.", appExe);
            }

            ProcessStartInfo info = new ProcessStartInfo();
            info.FileName = appExe;
            info.WorkingDirectory = extractRoot;
            info.UseShellExecute = false;
            info.EnvironmentVariables["PORTABLE_EXECUTABLE_FILE"] = exePath;
            info.EnvironmentVariables["PORTABLE_EXECUTABLE_DIR"] = Path.GetDirectoryName(exePath);
            Process.Start(info);

            return 0;
        }
        catch (Exception error)
        {
            MessageBox.Show("Zahpy Business Pro could not be launched.\n\n" + error.Message, "Zahpy Business Pro Standalone", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    private static long ReadPayloadLength(string exePath)
    {
        using (FileStream input = File.OpenRead(exePath))
        {
            if (input.Length < Marker.Length + 8)
            {
                throw new Exception("Standalone app payload is missing.");
            }

            input.Seek(-8, SeekOrigin.End);
            byte[] lengthBytes = new byte[8];
            ReadExact(input, lengthBytes, lengthBytes.Length);
            long payloadLength = BitConverter.ToInt64(lengthBytes, 0);

            if (payloadLength <= 0)
            {
                throw new Exception("Standalone app payload length is invalid.");
            }

            return payloadLength;
        }
    }

    private static void ExtractPayload(string exePath, string outputPath)
    {
        using (FileStream input = File.OpenRead(exePath))
        {
            if (input.Length < Marker.Length + 8)
            {
                throw new Exception("Standalone app payload is missing.");
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
                    throw new Exception("Standalone app payload marker is invalid.");
                }
            }

            long payloadStart = input.Length - 8 - Marker.Length - payloadLength;
            if (payloadLength <= 0 || payloadStart < 0)
            {
                throw new Exception("Standalone app payload length is invalid.");
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
                        throw new EndOfStreamException("Standalone app payload ended unexpectedly.");
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
}
"@

Set-Content -LiteralPath $sourcePath -Value $csharp -Encoding UTF8

$compileArgs = @(
  "/nologo",
  "/target:winexe",
  "/platform:anycpu",
  "/reference:System.Windows.Forms.dll",
  "/reference:System.Drawing.dll",
  "/reference:System.IO.Compression.dll",
  "/reference:System.IO.Compression.FileSystem.dll",
  "/out:$stubExe",
  $sourcePath
)

if ($hasIcon) {
  $compileArgs += "/win32icon:$iconPath"
}

& $csc @compileArgs

if (!(Test-Path -LiteralPath $stubExe)) {
  throw "Portable stub was not compiled: $stubExe"
}

Copy-Item -LiteralPath $stubExe -Destination $portableExe -Force

$marker = [Text.Encoding]::ASCII.GetBytes("ZAHPY_PORTABLE_V1")
$payloadLength = (Get-Item -LiteralPath $payloadZip).Length
$lengthBytes = [BitConverter]::GetBytes([Int64]$payloadLength)
$outStream = [IO.File]::Open($portableExe, [IO.FileMode]::Append, [IO.FileAccess]::Write)

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

if (!(Test-Path -LiteralPath $portableExe)) {
  throw "Standalone portable app was not created: $portableExe"
}

Write-Host "Standalone portable app written to $portableExe"
