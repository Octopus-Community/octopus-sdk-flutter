import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Private Android bridge: a retained view must stop handling system Back while
/// its tab is hidden by Visibility / IndexedStack, TickerMode is disabled, or
/// a host route covers it.
class OctopusViewVisibility extends StatefulWidget {
  const OctopusViewVisibility({
    super.key,
    required this.builder,
    this.isVisible = true,
  });

  final Widget Function(ValueChanged<int> onCreated) builder;
  final bool isVisible;

  @override
  State<OctopusViewVisibility> createState() => _OctopusViewVisibilityState();
}

class _OctopusViewVisibilityState extends State<OctopusViewVisibility> {
  MethodChannel? _channel;
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateVisibility();
  }

  @override
  void didUpdateWidget(OctopusViewVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) _updateVisibility();
  }

  void _updateVisibility() {
    final visible =
        widget.isVisible &&
        // TickerMode.valuesOf needs Flutter 3.35; the package floor is 3.10.
        // ignore: deprecated_member_use
        TickerMode.of(context) &&
        Visibility.of(context) &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (_visible != visible) {
      _visible = visible;
      _sendVisibility();
    }
  }

  void _onCreated(int id) {
    if (!mounted) return;
    _channel = MethodChannel('octopus_sdk_flutter/native_view/$id');
    _sendVisibility();
  }

  void _sendVisibility() {
    _channel?.invokeMethod<void>('setVisible', _visible).catchError((
      Object error,
      StackTrace stack,
    ) {
      if (!mounted) return;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'octopus_sdk_flutter',
          context: ErrorDescription(
            'updating embedded Android view visibility',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(_onCreated);
}
