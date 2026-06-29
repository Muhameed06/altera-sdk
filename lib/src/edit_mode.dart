import 'package:flutter/material.dart';

import 'bridge_client.dart';
import 'layout_node.dart';
import 'layout_state.dart';
import 'remote_renderer.dart';
import 'tree_ops.dart';

/// Drives in-simulator editing: holds the current selection and publishes tree
/// mutations (move / reposition) back through the [BridgeClient]. The actual
/// tree lives in [LayoutState]; this just reads it, transforms the JSON, and
/// sends a `layout_set`.
class RemoteEditController {
  RemoteEditController({required this.state, required this.client, required this.screen});

  final LayoutState state;
  final BridgeClient client;
  final String screen;

  final ValueNotifier<String?> selected = ValueNotifier<String?>(null);

  Map<String, dynamic>? get _tree => state.treeFor(screen)?.toJson();

  void select(String? id) {
    selected.value = id;
    client.select(screen, id);
  }

  void _publish(Map<String, dynamic> tree) => client.setTree(screen, tree);

  /// Move [id] into flow container [parentId] at [index].
  void move(String id, String parentId, int index) {
    final t = _tree;
    if (t == null) return;
    _publish(moveNode(t, id, parentId, index));
  }

  /// Drop [id] into free container [parentId] at the given local offset.
  void dropFree(String id, String parentId, Offset local) {
    var t = _tree;
    if (t == null) return;
    t = moveNode(t, id, parentId, -1);
    t = setFrame(t, id, {'left': local.dx.roundToDouble(), 'top': local.dy.roundToDouble()});
    _publish(t);
  }

  /// Commit a new absolute position for a node already in a free container.
  void setNodeFrame(String id, double left, double top) {
    final t = _tree;
    if (t == null) return;
    _publish(setFrame(t, id, {'left': left.roundToDouble(), 'top': top.roundToDouble()}));
  }

  void dispose() => selected.dispose();
}

/// Render hooks that overlay drag handles, drop zones, free-drag and selection
/// outlines on the live widget tree.
class EditRenderHooks extends RenderHooks {
  EditRenderHooks(this.c, {this.chrome = true});

  final RemoteEditController c;

  /// When false the device stays functionally editable (tap-to-select +
  /// geometry) but draws NO on-device edit affordances — no outlines, drag
  /// handles or drop zones. Used for a clean "mirror target" edited entirely
  /// from the dashboard.
  final bool chrome;

  @override
  bool get active => true;

  @override
  Widget decorate(BuildContext context, LayoutNode node, ContainerNode? parent, Widget child) {
    // No dashboard editor connected → the app behaves like a normal app: no
    // selection, no outlines, no drag handles. (Re-enables instantly when an
    // editor reconnects — RemoteUI rebuilds on editorPresent changes.)
    if (!c.client.editorPresent.value) return child;

    final isRoot = parent == null;
    final inFree = parent?.mode == ContainerMode.free;

    Widget wrapped = _Selectable(controller: c, nodeId: node.id, showBorder: chrome, child: child);

    // Chromeless: keep tap-to-select only — no outline, drag handle or pan.
    if (!chrome) return wrapped;

    if (isRoot) return wrapped;

    if (inFree) {
      // Free children pan to reposition.
      return _FreePannable(
        controller: c,
        node: node,
        child: wrapped,
      );
    }

    // Flow children: leaves/text drag by body; containers drag by a corner handle.
    if (node is! ContainerNode) {
      return _draggable(node.id, wrapped);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        wrapped,
        Positioned(
          top: -6,
          left: -6,
          child: _draggable(
            node.id,
            const _HandleChip(),
            feedbackLabel: 'group',
          ),
        ),
      ],
    );
  }

  Widget _draggable(String id, Widget child, {String? feedbackLabel}) {
    return Draggable<String>(
      data: id,
      dragAnchorStrategy: childDragAnchorStrategy,
      feedback: _DragFeedback(label: feedbackLabel ?? id),
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      child: child,
    );
  }

  @override
  List<Widget> assembleFlow(BuildContext context, ContainerNode parent, Axis axis,
      List<LayoutNode> nodes, List<Widget> widgets) {
    if (!chrome || !c.client.editorPresent.value) return super.assembleFlow(context, parent, axis, nodes, widgets);
    final expand = parent.props.expandChildren ?? true;
    final out = <Widget>[];
    for (var i = 0; i <= nodes.length; i++) {
      out.add(_DropZone(controller: c, parentId: parent.id, index: i, axis: axis));
      if (i < nodes.length) {
        final isRowItem = axis == Axis.horizontal && nodes[i] is! ContainerNode;
        out.add(isRowItem && expand ? Expanded(child: widgets[i]) : widgets[i]);
      }
    }
    return out;
  }

  @override
  Widget decorateFreeSurface(BuildContext context, ContainerNode parent, Widget stack) {
    if (!chrome || !c.client.editorPresent.value) return stack;
    return _FreeDropSurface(controller: c, parentId: parent.id, child: stack);
  }
}

// ── selection outline + tap-to-select ───────────────────────────────────────
class _Selectable extends StatelessWidget {
  const _Selectable({required this.controller, required this.nodeId, required this.child, this.showBorder = true});
  final RemoteEditController controller;
  final String nodeId;
  final Widget child;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    // Chromeless: tap-to-select with no visible outline.
    if (!showBorder) {
      return GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () => controller.select(nodeId),
        child: child,
      );
    }
    return ValueListenableBuilder<String?>(
      valueListenable: controller.selected,
      builder: (context, sel, _) {
        final selected = sel == nodeId;
        return GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: () => controller.select(nodeId),
          child: Container(
            foregroundDecoration: BoxDecoration(
              border: Border.all(
                color: selected ? const Color(0xFF5B8CFF) : const Color(0x33FFFFFF),
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

// ── drop target between flow children ───────────────────────────────────────
class _DropZone extends StatefulWidget {
  const _DropZone({required this.controller, required this.parentId, required this.index, required this.axis});
  final RemoteEditController controller;
  final String parentId;
  final int index;
  final Axis axis;

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) {
        setState(() => _hover = true);
        return true;
      },
      onLeave: (_) => setState(() => _hover = false),
      onAcceptWithDetails: (d) {
        setState(() => _hover = false);
        widget.controller.move(d.data, widget.parentId, widget.index);
      },
      builder: (context, candidate, rejected) {
        final active = _hover || candidate.isNotEmpty;
        final thickness = active ? 24.0 : 8.0;
        return Container(
          width: widget.axis == Axis.horizontal ? thickness : double.infinity,
          height: widget.axis == Axis.vertical ? thickness : double.infinity,
          constraints: widget.axis == Axis.vertical
              ? const BoxConstraints(minHeight: 8)
              : const BoxConstraints(minWidth: 8),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: active ? const Color(0x335B8CFF) : Colors.transparent,
            border: active ? Border.all(color: const Color(0xFF5B8CFF)) : null,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      },
    );
  }
}

// ── free-mode drop surface (drop a flow node into a free container) ──────────
class _FreeDropSurface extends StatelessWidget {
  const _FreeDropSurface({required this.controller, required this.parentId, required this.child});
  final RemoteEditController controller;
  final String parentId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onAcceptWithDetails: (d) {
        final box = context.findRenderObject() as RenderBox?;
        final local = box?.globalToLocal(d.offset) ?? Offset.zero;
        controller.dropFree(d.data, parentId, local);
      },
      builder: (context, _, __) => child,
    );
  }
}

// ── free child: pan to reposition ───────────────────────────────────────────
class _FreePannable extends StatefulWidget {
  const _FreePannable({required this.controller, required this.node, required this.child});
  final RemoteEditController controller;
  final LayoutNode node;
  final Widget child;

  @override
  State<_FreePannable> createState() => _FreePannableState();
}

class _FreePannableState extends State<_FreePannable> {
  Offset _drag = Offset.zero;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _drag,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onPanStart: (_) {
          widget.controller.select(widget.node.id);
          setState(() => _dragging = true);
        },
        onPanUpdate: (d) => setState(() => _drag += d.delta),
        onPanEnd: (_) {
          final f = widget.node.frame;
          final left = (f?.left ?? 0) + _drag.dx;
          final top = (f?.top ?? 0) + _drag.dy;
          setState(() {
            _drag = Offset.zero;
            _dragging = false;
          });
          widget.controller.setNodeFrame(widget.node.id, left < 0 ? 0 : left, top < 0 ? 0 : top);
        },
        child: Opacity(opacity: _dragging ? 0.8 : 1, child: widget.child),
      ),
    );
  }
}

// ── little visuals ──────────────────────────────────────────────────────────
class _HandleChip extends StatelessWidget {
  const _HandleChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(color: Color(0xFF5B8CFF), shape: BoxShape.circle),
      child: const Icon(Icons.open_with, size: 12, color: Colors.white),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF5B8CFF),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
