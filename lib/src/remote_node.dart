import 'package:flutter/widgets.dart';

/// Declares an editable layout node. Each node has a stable [id] (used as the
/// key in the layout graph) and the [child] widget it renders.
///
/// `RemoteNode` is a lightweight descriptor consumed by [RemoteUI]; it is also
/// a real widget so it can be dropped straight into a `children:` list.
class RemoteNode extends StatelessWidget {
  const RemoteNode({required this.id, required this.child, super.key});

  /// Stable identifier, e.g. `"featured"`. Must be unique within a screen.
  final String id;

  /// The component rendered for this node.
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
