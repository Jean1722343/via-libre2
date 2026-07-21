class Bloqueo {
  final String id;
  final String estado; // 'activo' | 'programado' | 'finalizado'
  final String tipo; // 'manifestacion' | 'obra' | 'accidente' | 'conflicto' | 'derrumbe' | 'otro'
  final double lat;
  final double lng;
  final String descripcion;
  final String municipio;
  final String? fotoUrl;
  final String? iniciaEn;
  final String? rutaAlternaTexto;
  final bool verificado;
  final String? autorId;
  final String? autorRol;
  final String? autorNombre;
  final String? autorFoto;
  final String creadoEn;
  final String actualizadoEn;
  final int confirmacionesSigue;
  final int confirmacionesLiberado;
  final int expiraEn;

  Bloqueo({
    required this.id,
    required this.estado,
    required this.tipo,
    required this.lat,
    required this.lng,
    required this.descripcion,
    required this.municipio,
    this.fotoUrl,
    this.iniciaEn,
    this.rutaAlternaTexto,
    required this.verificado,
    this.autorId,
    this.autorRol,
    this.autorNombre,
    this.autorFoto,
    required this.creadoEn,
    required this.actualizadoEn,
    required this.confirmacionesSigue,
    required this.confirmacionesLiberado,
    required this.expiraEn,
  });

  factory Bloqueo.fromJson(Map<String, dynamic> json) {
    return Bloqueo(
      id: json['id'] as String,
      estado: json['estado'] as String? ?? 'activo',
      tipo: json['tipo'] as String? ?? 'otro',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      descripcion: json['descripcion'] as String? ?? '',
      municipio: json['municipio'] as String? ?? '',
      fotoUrl: json['foto_url'] as String?,
      iniciaEn: json['inicia_en'] as String?,
      rutaAlternaTexto: json['ruta_alterna_texto'] as String?,
      verificado: json['verificado'] as bool? ?? false,
      autorId: json['autor_id'] as String?,
      autorRol: json['autor_rol'] as String?,
      autorNombre: json['autor_nombre'] as String?,
      autorFoto: json['autor_foto'] as String?,
      creadoEn: json['creado_en'] as String? ?? '',
      actualizadoEn: json['actualizado_en'] as String? ?? '',
      confirmacionesSigue: json['confirmaciones_sigue'] as int? ?? 0,
      confirmacionesLiberado: json['confirmaciones_liberado'] as int? ?? 0,
      expiraEn: json['expira_en'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'estado': estado,
      'tipo': tipo,
      'lat': lat,
      'lng': lng,
      'descripcion': descripcion,
      'municipio': municipio,
      'foto_url': fotoUrl,
      'inicia_en': iniciaEn,
      'ruta_alterna_texto': rutaAlternaTexto,
      'verificado': verificado,
      'autor_id': autorId,
      'autor_rol': autorRol,
      'autor_nombre': autorNombre,
      'autor_foto': autorFoto,
      'creado_en': creadoEn,
      'actualizado_en': actualizadoEn,
      'confirmaciones_sigue': confirmacionesSigue,
      'confirmaciones_liberado': confirmacionesLiberado,
      'expira_en': expiraEn,
    };
  }
}

class Lugar {
  final String etiqueta;
  final double lat;
  final double lng;

  Lugar({
    required this.etiqueta,
    required this.lat,
    required this.lng,
  });

  factory Lugar.fromJson(Map<String, dynamic> json) {
    return Lugar(
      etiqueta: json['etiqueta'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class Coordenada {
  final double lat;
  final double lng;

  Coordenada({required this.lat, required this.lng});

  factory Coordenada.fromJson(Map<String, dynamic> json) {
    return Coordenada(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'lat': lat, 'lng': lng};
  }
}

class OpcionRuta {
  final bool libre;
  final double distanciaKm;
  final int duracionMin;
  final List<Coordenada> geometria;
  final List<Bloqueo> bloqueosEnRuta;

  OpcionRuta({
    required this.libre,
    required this.distanciaKm,
    required this.duracionMin,
    required this.geometria,
    required this.bloqueosEnRuta,
  });

  factory OpcionRuta.fromJson(Map<String, dynamic> json) {
    final resumen = json['resumen'] as Map<String, dynamic>?;
    final geomList = json['geometria'] as List<dynamic>? ?? [];
    final bloqueosList = json['bloqueos_en_ruta'] as List<dynamic>? ?? [];

    return OpcionRuta(
      libre: json['libre'] as bool? ?? true,
      distanciaKm: resumen != null ? (resumen['distancia_km'] as num).toDouble() : 0.0,
      duracionMin: resumen != null ? (resumen['duracion_min'] as num).toInt() : 0,
      geometria: geomList.map((e) => Coordenada.fromJson(e as Map<String, dynamic>)).toList(),
      bloqueosEnRuta: bloqueosList.map((e) => Bloqueo.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ResultadoRuta {
  final Coordenada origen;
  final Coordenada destino;
  final OpcionRuta directa;
  final List<OpcionRuta> alternativas;

  ResultadoRuta({
    required this.origen,
    required this.destino,
    required this.directa,
    required this.alternativas,
  });

  factory ResultadoRuta.fromJson(Map<String, dynamic> json) {
    final altList = json['alternativas'] as List<dynamic>? ?? [];
    return ResultadoRuta(
      origen: Coordenada.fromJson(json['origen'] as Map<String, dynamic>),
      destino: Coordenada.fromJson(json['destino'] as Map<String, dynamic>),
      directa: OpcionRuta.fromJson(json['directa'] as Map<String, dynamic>),
      alternativas: altList.map((e) => OpcionRuta.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
