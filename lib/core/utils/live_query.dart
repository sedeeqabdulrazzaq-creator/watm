import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

typedef DocumentStream = Stream<DocumentSnapshot<Map<String, dynamic>>>;
typedef QueryStream = Stream<QuerySnapshot<Map<String, dynamic>>>;

/// Firestore listeners that survive widget rebuilds.
///
/// `reference.snapshots()` returns a brand new stream object on every call, so
/// calling it inside `build()` makes `StreamBuilder` cancel its listener and
/// open a fresh one each time the widget rebuilds. That costs billed reads and
/// flashes a loading spinner over data the app already had — and the dashboard
/// rebuilds often, because the user document is written on every save.
///
/// [LiveQuery] keeps one listener per path, always hands back the *same* stream
/// object (so `StreamBuilder` never resubscribes), and replays the latest
/// snapshot to any new subscriber so switching tabs shows data immediately.
class LiveQuery {
  LiveQuery._();

  static final Map<String, _CachedStream<DocumentSnapshot<Map<String, dynamic>>>>
      _documents = {};
  static final Map<String, _CachedStream<QuerySnapshot<Map<String, dynamic>>>>
      _queries = {};

  /// A live document, cached by its Firestore path.
  static DocumentStream doc(
    DocumentReference<Map<String, dynamic>> reference,
  ) =>
      _documents
          .putIfAbsent(
            reference.path,
            () => _CachedStream(reference.snapshots()),
          )
          .stream;

  /// A live query, cached by [key].
  ///
  /// [key] must describe the query completely — collection, filters, ordering
  /// and limit. Two different queries sharing a key would silently share one
  /// listener and one set of results.
  static QueryStream query(
    String key,
    Query<Map<String, dynamic>> query,
  ) =>
      _queries
          .putIfAbsent(key, () => _CachedStream(query.snapshots()))
          .stream;

  /// Drops every cached listener.
  ///
  /// Called when the signed-in account changes: the previous user's listeners
  /// would otherwise keep running against security rules that now deny them.
  static void reset() {
    for (final cached in _documents.values) {
      cached.dispose();
    }
    for (final cached in _queries.values) {
      cached.dispose();
    }
    _documents.clear();
    _queries.clear();
  }
}

class _CachedStream<T> {
  _CachedStream(Stream<T> source) {
    _subscription = source.listen(
      (event) {
        _latest = event;
        _hasLatest = true;
        if (!_controller.isClosed) _controller.add(event);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_controller.isClosed) _controller.addError(error, stackTrace);
      },
    );
  }

  final StreamController<T> _controller = StreamController<T>.broadcast();
  late final StreamSubscription<T> _subscription;
  T? _latest;
  bool _hasLatest = false;

  /// One stable stream object, shared by every subscriber.
  ///
  /// `MultiStreamController.add` delivers asynchronously, so replaying the
  /// cached snapshot here can never call `setState` while a widget is still
  /// subscribing.
  late final Stream<T> stream = Stream<T>.multi((controller) {
    if (_hasLatest) controller.add(_latest as T);
    final subscription = _controller.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  });

  void dispose() {
    _subscription.cancel();
    _controller.close();
  }
}
