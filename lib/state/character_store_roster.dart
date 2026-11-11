part of 'character_store.dart';

/// Roster: alta/baja/selección de personajes y el flujo de importación
/// desde texto (la respuesta de una IA o un .json pegado a mano).
///
/// La importación valida ANTES de tocar el roster: si hay errores
/// bloqueantes la ficha no entra y la UI le muestra al jugador el
/// informe; los warnings no bloquean (el wizard de Etapa 3 los lista
/// con vista previa antes de confirmar).
extension CharacterStoreRoster on CharacterStore {
  /// Cambia el personaje activo. No hace nada si el índice está fuera
  /// de rango, así el selector de la UI puede llamarlo sin validar.
  void switchCharacter(int index) {
    if (index < 0 || index >= roster.length) return;
    _activeIndex = index;
    _notifyAndPersist();
  }

  /// Elimina un personaje del roster y reajusta el índice activo para
  /// no dejar el HUD apuntando al vacío.
  void deleteCharacter(int index) {
    if (index < 0 || index >= roster.length) return;

    roster.removeAt(index);

    if (roster.isEmpty) {
      _activeIndex = 0; // sin personajes: activeCharacter pasa a null
    } else if (index <= _activeIndex) {
      // Se borró el activo o uno anterior: desplazar para no salirse.
      _activeIndex = (_activeIndex - 1).clamp(0, roster.length - 1);
    }

    _notifyAndPersist();
  }

  /// Añade una ficha ya construida al roster y la deja como activa.
  void addCharacter(CharacterModel character) {
    roster.add(character);
    _activeIndex = roster.length - 1;
    _notifyAndPersist();
  }

  /// Importa desde texto pegado (JSON, con o sin basura de IA alrededor).
  ///
  /// Devuelve el resultado de la validación TAL CUAL: si `isOk`, la
  /// ficha ya quedó añadida y seleccionada y el resultado trae los
  /// warnings para mostrar; si no, el roster quedó intacto y el
  /// resultado trae los errores bloqueantes. La UI no tiene que
  /// revalidar nada.
  CharacterValidationResult importCharacterFromText(String rawText) {
    final result = CharacterValidator.parseAndValidate(rawText);
    if (result.isOk) {
      addCharacter(result.character!);
    }
    return result;
  }

  /// Reemplaza la ficha en [index] por [character] — ya validada por la
  /// UI (el wizard valida en la vista previa y recién commitea al
  /// confirmar). Si el índice ya no es válido (el roster cambió mientras
  /// el wizard estaba abierto), la añade al final en vez de fallar.
  void replaceCharacter(int index, CharacterModel character) {
    if (index < 0 || index >= roster.length) {
      addCharacter(character);
      return;
    }
    roster[index] = character;
    _activeIndex = index;
    _notifyAndPersist();
  }

  /// Variante texto de [replaceCharacter] para quien ya tiene crudo lo
  /// que devolvió la IA (flujo "pegar el prompt → la IA responde
  /// corregido"): valida y, si pasó, reemplaza sin duplicar la entrada.
  CharacterValidationResult replaceCharacterFromText(
    int index,
    String rawText,
  ) {
    final result = CharacterValidator.parseAndValidate(rawText);
    if (result.isOk) replaceCharacter(index, result.character!);
    return result;
  }

  /// Guarda (o sustituye) el enlace de Nivel20 del personaje activo.
  void updateNivel20Link(String url) {
    final character = activeCharacter;
    if (character == null) return;
    character.basicInfo.nivel20Link = url;
    _notifyAndPersist();
  }
}
