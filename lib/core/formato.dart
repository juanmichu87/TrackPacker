String _dos(int n) => n.toString().padLeft(2, '0');

/// dd/MM/yyyy (hora local del dispositivo)
String fecha(DateTime d) {
  final l = d.toLocal();
  return '${_dos(l.day)}/${_dos(l.month)}/${l.year}';
}

/// dd/MM/yyyy HH:mm, formato europeo 24h (hora local del dispositivo)
String fechaHora(DateTime d) {
  final l = d.toLocal();
  return '${fecha(l)} ${_dos(l.hour)}:${_dos(l.minute)}';
}

/// Formatos de código de barras (enum formato_codigo de la base de datos).
const formatosCodigo = {
  'code128': 'Code 128',
  'code39': 'Code 39',
  'code93': 'Code 93',
  'codabar': 'Codabar',
  'ean8': 'EAN-8',
  'ean13': 'EAN-13',
  'upca': 'UPC-A',
  'upce': 'UPC-E',
  'itf': 'ITF',
  'qr': 'QR',
  'datamatrix': 'Data Matrix',
  'pdf417': 'PDF417',
  'aztec': 'Aztec',
};
