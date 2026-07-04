import 'package:qr/qr.dart';

/// Renders [data] as a scannable QR code for the terminal.
String renderQrAscii(String data, {int quietZone = 2}) {
  final qr = QrCode.fromData(
    data: data,
    errorCorrectLevel: QrErrorCorrectLevel.M,
  );
  final image = QrImage(qr);
  final modules = image.moduleCount;
  final size = modules + quietZone * 2;

  bool dark(int row, int col) {
    final r = row - quietZone;
    final c = col - quietZone;
    if (r < 0 || c < 0 || r >= modules || c >= modules) return false;
    return image.isDark(r, c);
  }

  const reset = '\x1B[0m';
  const black = 0;
  const white = 15;

  final buffer = StringBuffer();
  for (var row = 0; row < size; row += 2) {
    for (var col = 0; col < size; col++) {
      final top = dark(row, col);
      final bottom = (row + 1 < size) && dark(row + 1, col);
      final fg = top ? black : white;
      final bg = bottom ? black : white;
      buffer.write('\x1B[38;5;${fg}m\x1B[48;5;${bg}m▀');
    }
    buffer.writeln(reset);
  }
  return buffer.toString();
}
