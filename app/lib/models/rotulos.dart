/// Converte os códigos gravados no Firestore (`peso_corporal`, `haltere`...)
/// em texto para exibição.
class Rotulos {
  static const _equipamento = {
    'haltere': 'Halteres',
    'barra': 'Barra',
    'cabo': 'Cabo',
    'peso_corporal': 'Peso corporal',
    'maquina': 'Máquina',
    'smith': 'Smith',
    'banco': 'Banco',
    'banco_reto': 'Banco reto',
    'banco_inclinado': 'Banco inclinado',
    'banco_declinado': 'Banco declinado',
    'banco_romano': 'Banco romano',
    'barra_fixa': 'Barra fixa',
    'bola': 'Bola suíça',
    'maquina_voador': 'Voador',
    'maquina_t_bar': 'Máquina T-bar',
    'parede': 'Parede',
  };

  static const _musculo = {
    'peito': 'Peito',
    'costas': 'Costas',
    'costas_media': 'Costas (meio)',
    'ombros': 'Ombros',
    'biceps': 'Bíceps',
    'triceps': 'Tríceps',
    'antebraco': 'Antebraço',
    'core': 'Core',
    'lombar': 'Lombar',
    'quadriceps': 'Quadríceps',
    'posterior_coxa': 'Posterior de coxa',
    'gluteos': 'Glúteos',
    'panturrilha': 'Panturrilha',
    'trapezio': 'Trapézio',
    'pescoco': 'Pescoço',
    'flexores_quadril': 'Flexores do quadril',
    'adutores': 'Adutores',
    'obliquos': 'Oblíquos',
  };

  static const _tipo = {
    'compound': 'Composto',
    'isolation': 'Isolado',
    'isometric': 'Isométrico',
    'continuo': 'Contínuo',
    'intervalado': 'Intervalado',
    'estatico': 'Estático',
    'dinamico': 'Dinâmico',
  };

  static const _plano = {
    'sagital': 'Sagital',
    'frontal': 'Frontal',
    'transversal': 'Transversal',
  };

  static const _vetor = {
    'vertical': 'Vertical',
    'horizontal': 'Horizontal',
    'angular': 'Angular',
  };

  static String equipamento(String c) => _equipamento[c] ?? _fallback(c);
  static String musculo(String c) => _musculo[c] ?? _fallback(c);
  static String tipo(String c) => _tipo[c] ?? _fallback(c);
  static String plano(String c) => _plano[c] ?? _fallback(c);
  static String vetor(String c) => _vetor[c] ?? _fallback(c);

  /// Equipamentos de um exercício numa linha só, sem repetições.
  static String equipamentos(List<String> codigos) =>
      codigos.map(equipamento).toSet().join(', ');

  static String _fallback(String c) {
    if (c.isEmpty) return c;
    final t = c.replaceAll('_', ' ');
    return t[0].toUpperCase() + t.substring(1);
  }
}
