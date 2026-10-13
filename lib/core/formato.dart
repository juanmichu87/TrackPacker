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

const _sinTilde = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

/// Acentos escritos como carácter aparte (A + ◌́), habituales al copiar texto
/// o escribir desde algunos teclados.
final _acentosCombinados = RegExp(r'[\u0300-\u036f]', unicode: true);

/// Texto para comparar en búsquedas: sin espacios a los lados, en minúsculas
/// y sin tildes («Las ÁGUILAS» → «las aguilas»).
String normalizarBusqueda(String texto) {
  final minusculas = texto.trim().toLowerCase().replaceAll(_acentosCombinados, '');
  final resultado = StringBuffer();
  for (final letra in minusculas.split('')) {
    resultado.write(_sinTilde[letra] ?? letra);
  }
  return resultado.toString();
}

/// ¿Contiene `texto` la búsqueda ya normalizada? (null nunca coincide)
bool coincideBusqueda(String? texto, String busquedaNormalizada) =>
    texto != null && normalizarBusqueda(texto).contains(busquedaNormalizada);

final _trozos = RegExp(r'\d+|\D+');

/// Orden natural: «Ruta 2» antes que «Ruta 10», sin distinguir mayúsculas.
int compararNatural(String a, String b) {
  final ta = _trozos.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final tb = _trozos.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < ta.length && i < tb.length; i++) {
    final na = int.tryParse(ta[i]);
    final nb = int.tryParse(tb[i]);
    final c = (na != null && nb != null) ? na.compareTo(nb) : ta[i].compareTo(tb[i]);
    if (c != 0) return c;
  }
  return ta.length.compareTo(tb.length);
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

/// «1 bulto», «3 bultos». Si el plural no es singular + «s», se indica.
String cantidad(int n, String singular, [String? plural]) =>
    '$n ${n == 1 ? singular : (plural ?? '${singular}s')}';
