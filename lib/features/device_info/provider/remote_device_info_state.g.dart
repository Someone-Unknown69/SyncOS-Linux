// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_device_info_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DeviceInfoNotifier)
final deviceInfoProvider = DeviceInfoNotifierProvider._();

final class DeviceInfoNotifierProvider
    extends $NotifierProvider<DeviceInfoNotifier, DeviceInfoState> {
  DeviceInfoNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceInfoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceInfoNotifierHash();

  @$internal
  @override
  DeviceInfoNotifier create() => DeviceInfoNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceInfoState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceInfoState>(value),
    );
  }
}

String _$deviceInfoNotifierHash() =>
    r'db470aa6fa9eaccdf46bf19b289da7399a0b0f73';

abstract class _$DeviceInfoNotifier extends $Notifier<DeviceInfoState> {
  DeviceInfoState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<DeviceInfoState, DeviceInfoState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DeviceInfoState, DeviceInfoState>,
              DeviceInfoState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
