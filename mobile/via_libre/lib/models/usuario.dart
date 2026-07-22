import 'package:flutter/material.dart';

class Usuario {
  final String id;
  final String email;
  final String nombre;
  final String rol; // 'usuario' | 'noticiero' | 'admin'
  final String? proveedor;
  final String? foto;
  final String? creadoEn;

  Usuario({
    required this.id,
    required this.email,
    required this.nombre,
    required this.rol,
    this.proveedor,
    this.foto,
    this.creadoEn,
  });

  bool get esAdmin => rol == 'admin';
  bool get esNoticiero => rol == 'noticiero';
  bool get esNoticieroOAdmin => rol == 'noticiero' || rol == 'admin';

  String get rolEtiqueta {
    switch (rol) {
      case 'admin':
        return 'Administrador';
      case 'noticiero':
        return 'Noticiero Oficial';
      default:
        return 'Vecino Reportero';
    }
  }

  Color get rolColor {
    switch (rol) {
      case 'admin':
        return const Color(0xFF8B5CF6); // Púrpura neón
      case 'noticiero':
        return const Color(0xFF3B82F6); // Azul brillante
      default:
        return const Color(0xFF10B981); // Esmeralda
    }
  }

  IconData get rolIcono {
    switch (rol) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'noticiero':
        return Icons.verified;
      default:
        return Icons.person_pin_circle;
    }
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      nombre: json['nombre'] as String? ?? 'Usuario',
      rol: json['rol'] as String? ?? 'usuario',
      proveedor: json['proveedor'] as String?,
      foto: json['foto'] as String?,
      creadoEn: json['creado_en'] as String? ?? json['creadoEn'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nombre': nombre,
      'rol': rol,
      'proveedor': proveedor,
      'foto': foto,
      'creado_en': creadoEn,
    };
  }
}
