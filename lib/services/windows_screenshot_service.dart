import 'dart:async';
import 'dart:io';

class WindowsScreenshotService {
  Future<File?> captureFullScreen(String savePath) async {
    try {
      final outputFile = File(savePath);

      await outputFile.parent.create(recursive: true);

      final safePath = savePath.replaceAll("'", "''");

      final psScript = '''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class DpiHelper
{
    [DllImport("user32.dll")]
    public static extern bool SetProcessDpiAwarenessContext(
        IntPtr dpiContext
    );
}
"@

# Enable per-monitor DPI awareness so scaled displays
# are captured at their full physical resolution.
try {
    [DpiHelper]::SetProcessDpiAwarenessContext(
        [IntPtr](-4)
    ) | Out-Null
}
catch {
    # Continue if DPI awareness is unsupported.
}

\$bitmap = \$null
\$graphics = \$null

try {
    # Captures the complete virtual desktop, including
    # all connected monitors.
    \$bounds =
        [System.Windows.Forms.SystemInformation]::VirtualScreen

    if (
        \$bounds.Width -le 0 -or
        \$bounds.Height -le 0
    ) {
        throw "Invalid virtual desktop dimensions"
    }

    \$bitmap = New-Object System.Drawing.Bitmap(
        \$bounds.Width,
        \$bounds.Height,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )

    \$graphics =
        [System.Drawing.Graphics]::FromImage(\$bitmap)

    \$graphics.CopyFromScreen(
        \$bounds.Left,
        \$bounds.Top,
        0,
        0,
        \$bounds.Size,
        [System.Drawing.CopyPixelOperation]::SourceCopy
    )

    \$bitmap.Save(
        '$safePath',
        [System.Drawing.Imaging.ImageFormat]::Png
    )

    Write-Output (
        "SCREENSHOT_SUCCESS " +
        \$bounds.Width +
        "x" +
        \$bounds.Height
    )
}
catch {
    Write-Error \$_.Exception.Message
    exit 1
}
finally {
    if (\$graphics -ne \$null) {
        \$graphics.Dispose()
    }

    if (\$bitmap -ne \$null) {
        \$bitmap.Dispose()
    }
}
''';

      print('Windows screenshot capture started');
      print('Screenshot destination: $savePath');

      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-STA',
          '-Command',
          psScript,
        ],
        runInShell: false,
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException(
            'PowerShell screenshot capture timed out.',
          );
        },
      );

      print('PowerShell exit code: ${result.exitCode}');

      final stdoutText = result.stdout.toString().trim();
      final stderrText = result.stderr.toString().trim();

      if (stdoutText.isNotEmpty) {
        print('PowerShell output: $stdoutText');
      }

      if (stderrText.isNotEmpty) {
        print('PowerShell error: $stderrText');
      }

      if (result.exitCode != 0) {
        print(
          'Screenshot failed because PowerShell returned an error.',
        );
        return null;
      }

      if (!await outputFile.exists()) {
        print('Screenshot file was not created.');
        return null;
      }

      final fileSize = await outputFile.length();

      if (fileSize <= 0) {
        print('Screenshot file was created but is empty.');
        await outputFile.delete();
        return null;
      }

      print(
        'Screenshot captured successfully: $fileSize bytes',
      );

      return outputFile;
    } catch (error, stackTrace) {
      print('Windows screenshot exception: $error');
      print(stackTrace);
      return null;
    }
  }
}