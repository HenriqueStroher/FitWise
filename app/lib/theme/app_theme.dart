import 'package:flutter/material.dart';

/// Paleta e tipografia do app. Tudo que é cor ou estilo de texto sai daqui,
/// para que as telas não repitam valores soltos.
class AppCores {
  static const fundo        = Color(0xFF0C0C0D);
  static const superficie   = Color(0xFF161618);
  static const superficieAlta = Color(0xFF1F1F22);
  static const linha        = Color(0xFF26262A);
  static const texto        = Color(0xFFF4F4F1);
  static const textoSuave   = Color(0xFF9B9BA0);
  static const textoApagado = Color(0xFF616167);
  static const destaque     = Color(0xFFD4FF3A);
  static const sobreDestaque = Color(0xFF0C0C0D);
  static const erro         = Color(0xFFFF7A6B);

  /// Fundo dos painéis de ilustração. As imagens são traço preto sobre
  /// branco; com BlendMode.multiply o branco assume esta cor.
  static const papel        = Color(0xFFECECE6);
}

class AppFontes {
  static const display  = 'ArchivoExpanded';
  static const titulo   = 'Archivo';
  static const corpo    = 'Inter';
}

class AppTexto {
  static const _tnum = [FontFeature.tabularFigures()];

  static TextStyle display(double tamanho, {Color cor = AppCores.texto}) => TextStyle(
        fontFamily: AppFontes.display,
        fontWeight: FontWeight.w900,
        fontSize: tamanho,
        height: 0.95,
        letterSpacing: -0.5,
        color: cor,
      );

  static TextStyle titulo(double tamanho,
          {Color cor = AppCores.texto, FontWeight peso = FontWeight.w800}) =>
      TextStyle(
        fontFamily: AppFontes.titulo,
        fontWeight: peso,
        fontSize: tamanho,
        height: 1.1,
        letterSpacing: -0.3,
        color: cor,
      );

  /// Rótulo curto em caixa alta (seções, metadados).
  static const rotulo = TextStyle(
    fontFamily: AppFontes.corpo,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    letterSpacing: 1.4,
    color: AppCores.textoSuave,
  );

  static const corpo = TextStyle(
    fontFamily: AppFontes.corpo,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.55,
    color: AppCores.textoSuave,
  );

  static const item = TextStyle(
    fontFamily: AppFontes.corpo,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 1.3,
    color: AppCores.texto,
  );

  static const meta = TextStyle(
    fontFamily: AppFontes.corpo,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    height: 1.3,
    color: AppCores.textoSuave,
    fontFeatures: _tnum,
  );

  static const numero = TextStyle(
    fontFamily: AppFontes.titulo,
    fontWeight: FontWeight.w700,
    fontSize: 13,
    fontFeatures: _tnum,
    color: AppCores.textoApagado,
  );
}

ThemeData construirTema() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppFontes.corpo,
    scaffoldBackgroundColor: AppCores.fundo,
    colorScheme: const ColorScheme.dark(
      surface: AppCores.fundo,
      primary: AppCores.destaque,
      onPrimary: AppCores.sobreDestaque,
      secondary: AppCores.destaque,
      onSurface: AppCores.texto,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppCores.destaque,
      selectionColor: Color(0x55D4FF3A),
      selectionHandleColor: AppCores.destaque,
    ),
  );
}

/// Larguras de quebra do layout responsivo.
class AppLayout {
  static const larguraMaxima = 1080.0;
  static const larguraLeitura = 720.0;

  static double margem(double largura) => largura >= 720 ? 32 : 20;

  /// Recuo lateral que centraliza o conteúdo em [maxima] — para slivers,
  /// que não podem ser embrulhados pelo widget Conteudo.
  static double recuo(double largura, {double maxima = larguraMaxima}) {
    final sobra = (largura - maxima) / 2;
    final m = margem(largura);
    return sobra > m ? sobra : m;
  }
}
