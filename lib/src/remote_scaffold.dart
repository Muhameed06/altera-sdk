import 'package:flutter/material.dart';

import 'bridge_client.dart';
import 'layout_state.dart';
import 'protocol.dart';
import 'remote_ui.dart';

/// A whole editable page in one widget: a [Scaffold] whose body is a
/// [RemoteUI.auto] over [children]. Wrap the entire screen — app bar + content
/// — in a single widget, with every section editable and no `RemoteNode`/ids.
///
/// ```dart
/// home: RemoteScaffold(
///   screen: 'home',
///   config: kBridgeConfig,
///   editable: kEditable,
///   appBar: AppBar(title: const Text('Home')),
///   children: const [
///     FeaturedSection(key: ValueKey('featured')),
///     MusicSection(key: ValueKey('music')),
///   ],
/// )
/// ```
class RemoteScaffold extends StatelessWidget {
  const RemoteScaffold({
    required this.screen,
    required this.children,
    this.config,
    this.client,
    this.layoutState,
    this.defaultLayout,
    this.editable = false,
    this.showEditChrome = true,
    this.scrollable = true,
    this.padding = EdgeInsets.zero,
    this.appBar,
    this.backgroundColor,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    super.key,
  });

  final String screen;

  /// The page's top-level sections. Each becomes an editable node (id from its
  /// `ValueKey`, else `Type_index`).
  final List<Widget> children;

  final BridgeConfig? config;
  final BridgeClient? client;
  final LayoutState? layoutState;
  final DefaultLayoutBuilder? defaultLayout;
  final bool editable;

  /// When false (with [editable] true) the device renders clean — no on-device
  /// edit chrome — while staying editable from the dashboard mirror.
  final bool showEditChrome;
  final bool scrollable;

  /// Padding applied around the adopted content.
  final EdgeInsetsGeometry padding;

  // Standard Scaffold chrome — fully under your control, around the editable body.
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;

  @override
  Widget build(BuildContext context) {
    Widget body = RemoteUI.auto(
      screen: screen,
      config: config,
      client: client,
      layoutState: layoutState,
      defaultLayout: defaultLayout,
      editable: editable,
      showEditChrome: showEditChrome,
      scrollable: scrollable,
      children: children,
    );
    if (padding != EdgeInsets.zero) body = Padding(padding: padding, child: body);
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
      body: body,
    );
  }
}
