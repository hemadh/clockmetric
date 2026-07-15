import 'dart:io';

class WindowsScreenshotService {
  Future<File?> captureFullScreen(String savePath) async {
    final psScript = '''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

\$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
\$bitmap = New-Object System.Drawing.Bitmap \$bounds.Width, \$bounds.Height
\$graphics = [System.Drawing.Graphics]::FromImage(\$bitmap)
\$graphics.CopyFromScreen(\$bounds.Location, [System.Drawing.Point]::Empty, \$bounds.Size)
\$bitmap.Save("$savePath", [System.Drawing.Imaging.ImageFormat]::Png)
\$graphics.Dispose()
\$bitmap.Dispose()
''';

   await Process.run(
  'powershell',
  [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-Command',
    psScript,
  ],
);

    final file = File(savePath);

    if (await file.exists()) {
      return file;
    }

    return null;
  }
}