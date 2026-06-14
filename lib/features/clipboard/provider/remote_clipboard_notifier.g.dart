// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_clipboard_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RemoteClipboardNotifier)
final remoteClipboardProvider = RemoteClipboardNotifierProvider._();

final class RemoteClipboardNotifierProvider
    extends $NotifierProvider<RemoteClipboardNotifier, ClipboardObject?> {
  RemoteClipboardNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteClipboardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteClipboardNotifierHash();

  @$internal
  @override
  RemoteClipboardNotifier create() => RemoteClipboardNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClipboardObject? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClipboardObject?>(value),
    );
  }
}

String _$remoteClipboardNotifierHash() =>
    r'e792b0b2d355bb2128018ccf2f20247da1d59d31';

abstract class _$RemoteClipboardNotifier extends $Notifier<ClipboardObject?> {
  ClipboardObject? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ClipboardObject?, ClipboardObject?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ClipboardObject?, ClipboardObject?>,
              ClipboardObject?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
