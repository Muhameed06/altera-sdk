import 'package:flutter/material.dart';

import 'bridge_client.dart';
import 'layout_node.dart';
import 'protocol.dart';
import 'remote_ui.dart';

/// Describes one bottom-nav item.
class RemoteNavItem {
  const RemoteNavItem({required this.id, required this.icon, required this.label});
  final String id;
  final IconData icon;
  final String label;
}

/// A bottom navigation bar whose items are part of the layout graph — reorder,
/// hide, and restyle the tabs from the dashboard (region, e.g. `'bottombar'`),
/// exactly like [RemoteAppBar]. Tapping an item calls [onSelect].
///
/// ```dart
/// bottomNavigationBar: RemoteBottomBar(
///   region: 'bottombar',
///   client: kClient,
///   currentId: _currentId,
///   onSelect: (id) => setState(() => _currentId = id),
///   items: const [
///     RemoteNavItem(id: 'home', icon: Icons.home_rounded, label: 'Home'),
///     RemoteNavItem(id: 'search', icon: Icons.search_rounded, label: 'Search'),
///   ],
/// )
/// ```
class RemoteBottomBar extends StatelessWidget {
  const RemoteBottomBar({
    required this.region,
    required this.items,
    required this.currentId,
    required this.onSelect,
    this.config,
    this.client,
    this.backgroundColor,
    this.editable = false,
    this.showEditChrome = true,
    this.height = 64,
    super.key,
  }) : assert(config != null || client != null,
            'Provide either a BridgeConfig or a pre-built BridgeClient.');

  final String region;
  final List<RemoteNavItem> items;
  final String currentId;
  final ValueChanged<String> onSelect;
  final BridgeConfig? config;
  final BridgeClient? client;
  final Color? backgroundColor;
  final bool editable;

  /// Hide on-device edit chrome while staying dashboard-editable.
  final bool showEditChrome;
  final double height;

  @override
  Widget build(BuildContext context) {
    final widgets = [
      for (final it in items)
        _NavButton(key: ValueKey(it.id), item: it, selected: it.id == currentId, onTap: () => onSelect(it.id)),
    ];
    return Material(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
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
                  props: const ContainerProps(mainAxis: 'spaceAround', crossAxis: 'center', expandChildren: true),
                  children: [for (final id in palette) LeafNode(id: 'n_$id', ref: id)],
                ),
                children: widgets,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap, super.key});
  final RemoteNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = Theme.of(context).colorScheme.primary;
    final idle = (DefaultTextStyle.of(context).style.color ?? Colors.grey).withValues(alpha: 0.6);
    final color = selected ? active : idle;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(item.label,
                style: TextStyle(color: color, fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
