// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_battery_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BatteryNotifier)
final batteryProvider = BatteryNotifierProvider._();

final class BatteryNotifierProvider
    extends $NotifierProvider<BatteryNotifier, BatteryState> {
  BatteryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'batteryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$batteryNotifierHash();

  @$internal
  @override
  BatteryNotifier create() => BatteryNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BatteryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BatteryState>(value),
    );
  }
}

String _$batteryNotifierHash() => r'f4a3895f190f2f637069f51c36492b071d22b5f8';

abstract class _$BatteryNotifier extends $Notifier<BatteryState> {
  BatteryState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<BatteryState, BatteryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BatteryState, BatteryState>,
              BatteryState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
