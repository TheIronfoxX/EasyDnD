import 'dart:math';

/// Random falso determinístico para tests: devuelve los valores de
/// [outcomes] en orden (y da vueltas si se piden más). Los valores se
/// toman módulo el máximo pedido, así la misma lista sirve para dados
/// de caras distintas — lo importante es que la secuencia sea
/// reproducible.
///
/// `implements` (no `extends`): Random solo tiene constructores factory,
/// no se puede heredar de él con un constructor generativo.
class FakeRandom implements Random {
  final List<int> outcomes;
  int _cursor = 0;

  FakeRandom(this.outcomes);

  @override
  int nextInt(int max) {
    final value = outcomes[_cursor % outcomes.length];
    _cursor++;
    return value % max;
  }

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}
