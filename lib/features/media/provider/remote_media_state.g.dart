// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_media_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MusicNotifier)
final musicProvider = MusicNotifierProvider._();

final class MusicNotifierProvider
    extends $NotifierProvider<MusicNotifier, MediaInfo> {
  MusicNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'musicProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$musicNotifierHash();

  @$internal
  @override
  MusicNotifier create() => MusicNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaInfo value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaInfo>(value),
    );
  }
}

String _$musicNotifierHash() => r'9053235dd6fda7e9f0b2492c2dbeaa46a83024a4';

abstract class _$MusicNotifier extends $Notifier<MediaInfo> {
  MediaInfo build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MediaInfo, MediaInfo>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MediaInfo, MediaInfo>,
              MediaInfo,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
