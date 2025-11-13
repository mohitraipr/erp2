import 'dart:async';

import 'package:flutter/widgets.dart';

/// A lightweight subset of the Riverpod API used by this project.
///
/// The implementation below provides just enough features to support the
/// patterns in the UI (providers, state notifiers and future providers) without
/// depending on the external `flutter_riverpod` package.

// ---------------------------------------------------------------------------
// AsyncValue
// ---------------------------------------------------------------------------

class AsyncValue<T> {
  const AsyncValue._({
    this.value,
    this.error,
    this.stackTrace,
    required this.isLoading,
  });

  const AsyncValue.loading() : this._(isLoading: true);

  const AsyncValue.data(T value)
      : this._(value: value, isLoading: false);

  const AsyncValue.error(Object error, [StackTrace? stackTrace])
      : this._(
          error: error,
          stackTrace: stackTrace,
          isLoading: false,
        );

  final T? value;
  final Object? error;
  final StackTrace? stackTrace;
  final bool isLoading;

  R when<R>({
    required R Function(T data) data,
    required R Function(Object error, StackTrace? stackTrace) error,
    required R Function() loading,
  }) {
    if (isLoading) {
      return loading();
    }
    if (this.error != null) {
      return error(this.error!, stackTrace);
    }
    return data(value as T);
  }
}

// ---------------------------------------------------------------------------
// Provider infrastructure
// ---------------------------------------------------------------------------

abstract class ProviderListenable<T> {
  const ProviderListenable();

  _ProviderEntry<T> createEntry(_ProviderContainer container);
}

abstract class _ProviderEntry<T> extends ChangeNotifier {
  _ProviderEntry(this.container);

  final _ProviderContainer container;
  final List<VoidCallback> _disposeCallbacks = <VoidCallback>[];

  T get value;

  @mustCallSuper
  void addOnDispose(VoidCallback callback) {
    _disposeCallbacks.add(callback);
  }

  void initialize();

  T refresh();

  @mustCallSuper
  void disposeEntry() {
    for (final callback in _disposeCallbacks.reversed) {
      callback();
    }
    _disposeCallbacks.clear();
  }
}

class _ProviderContainer {
  final Map<ProviderListenable<Object?>, _ProviderEntry<Object?>> _entries = {};

  _ProviderEntry<T> _ensureEntry<T>(ProviderListenable<T> provider) {
    final existing = _entries[provider];
    if (existing != null) {
      return existing as _ProviderEntry<T>;
    }
    final entry = provider.createEntry(this);
    _entries[provider] = entry as _ProviderEntry<Object?>;
    entry.initialize();
    return entry;
  }

  T read<T>(ProviderListenable<T> provider) {
    final entry = _ensureEntry(provider);
    return entry.value;
  }

  T refresh<T>(ProviderListenable<T> provider) {
    final entry = _ensureEntry(provider);
    return entry.refresh();
  }

  void invalidate<T>(ProviderListenable<T> provider) {
    final entry = _ensureEntry(provider);
    entry.refresh();
  }

  void dispose() {
    for (final entry in _entries.values) {
      entry.disposeEntry();
    }
    _entries.clear();
  }
}

// ---------------------------------------------------------------------------
// ProviderScope & WidgetRef
// ---------------------------------------------------------------------------

class ProviderScope extends StatefulWidget {
  const ProviderScope({super.key, required this.child});

  final Widget child;

  static _ProviderContainer of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_ProviderScopeInherited>();
    if (inherited == null) {
      throw StateError('ProviderScope not found in context');
    }
    return inherited.container;
  }

  @override
  State<ProviderScope> createState() => _ProviderScopeState();
}

class _ProviderScopeState extends State<ProviderScope> {
  late final _ProviderContainer _container = _ProviderContainer();

  @override
  void dispose() {
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ProviderScopeInherited(
      container: _container,
      child: widget.child,
    );
  }
}

class _ProviderScopeInherited extends InheritedWidget {
  const _ProviderScopeInherited({
    required super.child,
    required this.container,
  });

  final _ProviderContainer container;

  @override
  bool updateShouldNotify(_ProviderScopeInherited oldWidget) => false;
}

abstract class WidgetRef {
  T watch<T>(ProviderListenable<T> provider);

  T read<T>(ProviderListenable<T> provider);

  void listen<T>(ProviderListenable<T> provider,
      void Function(T? previous, T next) listener);

  T refresh<T>(ProviderListenable<T> provider);

  void invalidate<T>(ProviderListenable<T> provider);

  void onDispose(VoidCallback callback);
}

class _ContainerRef implements WidgetRef {
  _ContainerRef(this._container, this._entry);

  final _ProviderContainer _container;
  final _ProviderEntry<dynamic> _entry;

  @override
  void invalidate<T>(ProviderListenable<T> provider) {
    _container.invalidate(provider);
  }

  @override
  void listen<T>(ProviderListenable<T> provider,
      void Function(T? previous, T next) listener) {
    final next = read(provider);
    listener(null, next);
  }

  @override
  void onDispose(VoidCallback callback) {
    _entry.addOnDispose(callback);
  }

  @override
  T read<T>(ProviderListenable<T> provider) {
    return _container.read(provider);
  }

  @override
  T refresh<T>(ProviderListenable<T> provider) {
    return _container.refresh(provider);
  }

  @override
  T watch<T>(ProviderListenable<T> provider) {
    return read(provider);
  }
}

class _Consumer extends StatefulWidget {
  const _Consumer({
    required this.builder,
    this.owner,
  });

  final Widget Function(BuildContext context, WidgetRef ref) builder;
  final _ConsumerStateOwner? owner;

  @override
  State<_Consumer> createState() => _ConsumerState();
}

abstract class _ConsumerStateOwner {
  bool get mounted;

  void markNeedsBuild();

  void registerDispose(VoidCallback callback);

  void updateRef(WidgetRef ref);
}

class _ConsumerState extends State<_Consumer> implements _ConsumerStateOwner {
  final Map<_ProviderEntry<dynamic>, VoidCallback> _watchDisposers = {};
  final List<VoidCallback> _disposeCallbacks = <VoidCallback>[];
  WidgetRef? _latestRef;

  @override
  void dispose() {
    for (final disposer in _watchDisposers.values) {
      disposer();
    }
    _watchDisposers.clear();
    for (final callback in _disposeCallbacks.reversed) {
      callback();
    }
    _disposeCallbacks.clear();
    super.dispose();
  }

  void _registerWatch(_ProviderEntry<dynamic> entry) {
    if (_watchDisposers.containsKey(entry)) {
      return;
    }
    void listener() {
      if (mounted) {
        setState(() {});
      }
    }

    entry.addListener(listener);
    _watchDisposers[entry] = () => entry.removeListener(listener);
  }

  void _registerListener(
    _ProviderEntry<dynamic> entry,
    void Function(dynamic previous, dynamic next) listener,
  ) {
    dynamic previous = entry.value;
    void handler() {
      final next = entry.value;
      listener(previous, next);
      previous = next;
    }

    entry.addListener(handler);
    _disposeCallbacks.add(() => entry.removeListener(handler));
  }

  @override
  Widget build(BuildContext context) {
    final container = ProviderScope.of(context);
    final ref = _WidgetRefImpl(
      container: container,
      state: this,
    );
    _latestRef = ref;
    widget.owner?.updateRef(ref);
    return widget.builder(context, ref);
  }

  @override
  void markNeedsBuild() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void registerDispose(VoidCallback callback) {
    _disposeCallbacks.add(callback);
  }

  @override
  void updateRef(WidgetRef ref) {
    _latestRef = ref;
  }
}

class _WidgetRefImpl implements WidgetRef {
  _WidgetRefImpl({
    required this.container,
    required this.state,
  });

  final _ProviderContainer container;
  final _ConsumerState state;

  @override
  void invalidate<T>(ProviderListenable<T> provider) {
    container.invalidate(provider);
  }

  @override
  void listen<T>(ProviderListenable<T> provider,
      void Function(T? previous, T next) listener) {
    final entry = container._ensureEntry(provider);
    state._registerListener(entry, listener);
    listener(null, entry.value);
  }

  @override
  void onDispose(VoidCallback callback) {
    state.registerDispose(callback);
  }

  @override
  T read<T>(ProviderListenable<T> provider) {
    final entry = container._ensureEntry(provider);
    return entry.value;
  }

  @override
  T refresh<T>(ProviderListenable<T> provider) {
    final entry = container._ensureEntry(provider);
    return entry.refresh();
  }

  @override
  T watch<T>(ProviderListenable<T> provider) {
    final entry = container._ensureEntry(provider);
    state._registerWatch(entry);
    return entry.value;
  }
}

// ---------------------------------------------------------------------------
// Consumer widgets
// ---------------------------------------------------------------------------

abstract class ConsumerWidget extends StatelessWidget {
  const ConsumerWidget({super.key});

  Widget buildWithRef(BuildContext context, WidgetRef ref);

  @override
  Widget build(BuildContext context) {
    return _Consumer(builder: buildWithRef);
  }
}

abstract class ConsumerStatefulWidget extends StatefulWidget {
  const ConsumerStatefulWidget({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState();
}

abstract class ConsumerState<T extends ConsumerStatefulWidget> extends State<T>
    implements _ConsumerStateOwner {
  late WidgetRef ref;
  final List<VoidCallback> _disposeCallbacks = <VoidCallback>[];

  @override
  Widget build(BuildContext context) {
    return _Consumer(
      owner: this,
      builder: (context, ref) {
        this.ref = ref;
        return buildWithRef(context, ref);
      },
    );
  }

  Widget buildWithRef(BuildContext context, WidgetRef ref);

  @override
  void markNeedsBuild() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void registerDispose(VoidCallback callback) {
    _disposeCallbacks.add(callback);
  }

  @override
  void updateRef(WidgetRef ref) {
    this.ref = ref;
  }

  @override
  void dispose() {
    for (final callback in _disposeCallbacks.reversed) {
      callback();
    }
    _disposeCallbacks.clear();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider implementations
// ---------------------------------------------------------------------------

class Provider<T> extends ProviderListenable<T> {
  Provider(this._create);

  final T Function(WidgetRef ref) _create;

  @override
  _ProviderEntry<T> createEntry(_ProviderContainer container) {
    return _SimpleProviderEntry<T>(container, _create);
  }
}

class _SimpleProviderEntry<T> extends _ProviderEntry<T> {
  _SimpleProviderEntry(super.container, this._create);

  final T Function(WidgetRef ref) _create;
  late T _value;

  @override
  void initialize() {
    final ref = _ContainerRef(container, this);
    _value = _create(ref);
  }

  @override
  T get value => _value;

  @override
  T refresh() {
    final ref = _ContainerRef(container, this);
    for (final callback in _disposeCallbacks.reversed) {
      callback();
    }
    _disposeCallbacks.clear();
    _value = _create(ref);
    notifyListeners();
    return _value;
  }

  @override
  void disposeEntry() {
    super.disposeEntry();
    if (_value is ChangeNotifier) {
      (_value as ChangeNotifier).dispose();
    }
  }
}

abstract class StateNotifier<T> {
  StateNotifier(this._state);

  final List<VoidCallback> _listeners = <VoidCallback>[];
  T _state;

  T get state => _state;

  set state(T value) {
    if (!identical(_state, value)) {
      _state = value;
      for (final listener in List<VoidCallback>.from(_listeners)) {
        listener();
      }
    }
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @mustCallSuper
  void dispose() {
    _listeners.clear();
  }
}

class StateNotifierProvider<TNotifier extends StateNotifier<T>, T>
    extends ProviderListenable<T> {
  StateNotifierProvider(this._create);

  final TNotifier Function(WidgetRef ref) _create;
  late final ProviderListenable<TNotifier> _notifierProvider =
      _StateNotifierControllerProvider<TNotifier, T>(this);

  @override
  _ProviderEntry<T> createEntry(_ProviderContainer container) {
    return _StateNotifierProviderEntry<TNotifier, T>(container, _create);
  }

  ProviderListenable<TNotifier> get notifier => _notifierProvider;
}

class _StateNotifierProviderEntry<TNotifier extends StateNotifier<T>, T>
    extends _ProviderEntry<T> {
  _StateNotifierProviderEntry(super.container, this._create);

  final TNotifier Function(WidgetRef ref) _create;
  late final TNotifier _notifier;
  late T _value;

  @override
  void initialize() {
    final ref = _ContainerRef(container, this);
    _notifier = _create(ref);
    _value = _notifier.state;
    _notifier.addListener(_handleNotifierChanged);
  }

  @override
  T get value => _value;

  TNotifier get notifier => _notifier;

  void _handleNotifierChanged() {
    final next = _notifier.state;
    if (!identical(next, _value)) {
      _value = next;
      notifyListeners();
    }
  }

  @override
  T refresh() {
    _notifier.removeListener(_handleNotifierChanged);
    _notifier.dispose();
    for (final callback in _disposeCallbacks.reversed) {
      callback();
    }
    _disposeCallbacks.clear();
    initialize();
    notifyListeners();
    return _value;
  }

  @override
  void disposeEntry() {
    super.disposeEntry();
    _notifier.removeListener(_handleNotifierChanged);
    _notifier.dispose();
  }
}

class _StateNotifierControllerProvider<TNotifier extends StateNotifier<T>, T>
    extends ProviderListenable<TNotifier> {
  _StateNotifierControllerProvider(this._parent);

  final StateNotifierProvider<TNotifier, T> _parent;

  @override
  _ProviderEntry<TNotifier> createEntry(_ProviderContainer container) {
    final parentEntry = container._ensureEntry<T>(_parent)
        as _StateNotifierProviderEntry<TNotifier, T>;
    return _StateNotifierAccessorEntry(parentEntry);
  }
}

class _StateNotifierAccessorEntry<TNotifier extends StateNotifier<Object?>, T>
    extends _ProviderEntry<TNotifier> {
  _StateNotifierAccessorEntry(this._source)
      : super(_source.container);

  final _StateNotifierProviderEntry<TNotifier, T> _source;

  @override
  void initialize() {}

  @override
  TNotifier get value => _source.notifier;

  @override
  TNotifier refresh() => _source.notifier;

  @override
  void disposeEntry() {}
}

class FutureProvider<T> extends ProviderListenable<AsyncValue<T>> {
  FutureProvider(this._create);

  final Future<T> Function(WidgetRef ref) _create;

  @override
  _ProviderEntry<AsyncValue<T>> createEntry(_ProviderContainer container) {
    return _FutureProviderEntry<T>(container, _create);
  }
}

class _FutureProviderEntry<T> extends _ProviderEntry<AsyncValue<T>> {
  _FutureProviderEntry(super.container, this._create);

  final Future<T> Function(WidgetRef ref) _create;
  AsyncValue<T> _state = const AsyncValue.loading();
  Completer<void>? _activeRequest;

  @override
  void initialize() {
    _fetch();
  }

  void _fetch() {
    _state = const AsyncValue<T>.loading();
    notifyListeners();
    final completer = Completer<void>();
    _activeRequest = completer;
    final ref = _ContainerRef(container, this);
    Future<T>(() => _create(ref)).then((value) {
      if (_activeRequest != completer) {
        return;
      }
      _state = AsyncValue<T>.data(value);
      notifyListeners();
      completer.complete();
    }).catchError((error, stackTrace) {
      if (_activeRequest != completer) {
        return;
      }
      _state = AsyncValue<T>.error(error, stackTrace);
      notifyListeners();
      completer.completeError(error, stackTrace);
    });
  }

  @override
  AsyncValue<T> get value => _state;

  @override
  AsyncValue<T> refresh() {
    _fetch();
    return _state;
  }

  @override
  void disposeEntry() {
    super.disposeEntry();
    _activeRequest = null;
  }
}

class FutureProviderFamily<T, Arg> {
  const FutureProviderFamily(this._create);

  final Future<T> Function(WidgetRef ref, Arg arg) _create;

  FutureProvider<T> call(Arg argument) {
    return _FutureProviderFamilyInstance<T, Arg>(this, argument);
  }
}

class _FutureProviderFamilyInstance<T, Arg> extends FutureProvider<T> {
  _FutureProviderFamilyInstance(this.family, this.argument)
      : super((ref) => family._create(ref, argument));

  final FutureProviderFamily<T, Arg> family;
  final Arg argument;

  @override
  bool operator ==(Object other) {
    return other is _FutureProviderFamilyInstance<T, Arg> &&
        other.family == family &&
        other.argument == argument;
  }

  @override
  int get hashCode => Object.hash(family, argument);
}
