import 'package:flutter/material.dart';

import 'bridge_client.dart';
import 'layout_node.dart';
import 'protocol.dart';
import 'remote_ui.dart';

/// An app bar with **full layout control**: its content is a free layout region
/// rendered by the same engine as the body. Put elements on the left and the
/// title on the right, group them in rows, change alignment, hide, restyle, or
/// free-position — all from the dashboard, no code change.
///
/// The default layout is a single row containing a title [TextNode] and one leaf
/// per element; rearrange it however you like.
///
/// ```dart
/// appBar: RemoteAppBar(
///   region: 'home.appbar',
///   client: kClient,
///   title: 'Home',
///   elements: const [
///     IconButton(key: ValueKey('search'),   icon: Icon(Icons.search),   onPressed: _noop),
///     IconButton(key: ValueKey('settings'), icon: Icon(Icons.settings), onPressed: _noop),
///   ],
/// )
/// ```
class RemoteAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RemoteAppBar({
    required this.region,
    required this.elements,
    this.title = '',
    this.config,
    this.client,
    this.backgroundColor,
    this.editable = false,
    this.showEditChrome = true,
    this.height = kToolbarHeight,
    super.key,
  }) : assert(config != null || client != null,
            'Provide either a BridgeConfig or a pre-built BridgeClient.');

  /// Bridge region id for this app bar (its own "screen"), e.g. `'home.appbar'`.
  final String region;

  /// The editable elements (icons, buttons, …). Give each a `ValueKey`.
  final List<Widget> elements;

  /// Default title text (an editable text node in the layout).
  final String title;

  final BridgeConfig? config;
  final BridgeClient? client;
  final Color? backgroundColor;

  /// Whether to also allow in-simulator drag editing of the app bar (off by
  /// default — the bar is short; edit it from the dashboard instead).
  final bool editable;

  /// Hide on-device edit chrome while staying dashboard-editable.
  final bool showEditChrome;

  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      toolbarHeight: height,
      // Crash-proof: the toolbar slot is a fixed height, but the editor could
      // arrange the content taller (e.g. switch to a column). OverflowBox gives
      // the content its natural size and ClipRect trims anything beyond the bar,
      // so a bad arrangement degrades gracefully instead of overflowing.
      title: SizedBox(
        height: height,
        width: double.infinity,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            maxHeight: double.infinity,
            child: RemoteUI.auto(
              screen: region,
              config: config,
              client: client,
              editable: editable,
              showEditChrome: showEditChrome,
              scrollable: false,
          defaultLayout: (palette) => ContainerNode(
            id: 'root',
            type: ContainerType.row,
            props: const ContainerProps(
              mainAxis: 'spaceBetween',
              crossAxis: 'center',
              padding: 8,
              gap: 4,
              expandChildren: false, // toolbar items keep their size
            ),
            children: [
              TextNode(id: '__title__', text: title),
              for (final id in palette) LeafNode(id: 'n_$id', ref: id),
            ],
          ),
              children: elements,
            ),
          ),
        ),
      ),
    );
  }
}
