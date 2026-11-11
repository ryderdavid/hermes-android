/// Remembers, per turn, whether the user unfolded or re-folded its steps.
///
/// A row cannot keep this in its own `State`. The chat list is a
/// `ListView.builder`: rows are rebuilt at other indexes as a turn streams,
/// evicted when they scroll out of the viewport, and rebuilt from scratch
/// when the history is refreshed. The projection asks this store instead, so
/// the choice follows the turn.
///
/// Keyed by the turn id from `ChatTurnFold`: the stored id of the turn's user
/// message, or the first tool call's identity until the server has stored the
/// turn. [alias] links the earlier id to the later one. `null` means the
/// default (a finished turn is folded), `true` unfolded, `false` folded by
/// hand.
class TurnFoldPins {
  static const maxPins = 100;
  final Map<String, bool> _pins = <String, bool>{};
  final Map<String, String> _aliases = <String, String>{};

  /// The choice the user made for [turnId], or `null` if they never touched
  /// that turn's fold line.
  bool? operator [](String turnId) => _pins[turnId];

  void pin(String turnId, bool unfolded) {
    _pins.remove(turnId);
    _pins[turnId] = unfolded;
    final alias = _aliases[turnId];
    if (alias != null) _put(alias, unfolded);
    _trim();
  }

  /// Link a turn's earlier id (an id-less first tool call, then its tool id)
  /// to its later durable one. The alias is retained so a tap made under the
  /// earlier id also follows a history refresh.
  void alias(String turnId, String durableId) {
    if (turnId == durableId) return;
    _aliases.remove(turnId);
    _aliases[turnId] = durableId;
    final choice = _pins[turnId];
    if (choice != null && !_pins.containsKey(durableId)) {
      _put(durableId, choice);
    }
    _trim();
  }

  void _put(String id, bool unfolded) {
    _pins.remove(id);
    _pins[id] = unfolded;
  }

  void _trim() {
    while (_pins.length > maxPins) {
      _pins.remove(_pins.keys.first);
    }
    while (_aliases.length > maxPins) {
      _aliases.remove(_aliases.keys.first);
    }
  }

  /// Forgets every choice, for when the conversation itself is replaced.
  void clear() {
    _pins.clear();
    _aliases.clear();
  }

  int get length => _pins.length;
}
