import 'package:flutter/material.dart';

import 'binding.dart';
import 'geometry_reporter.dart';
import 'layout_node.dart';
import 'registry.dart';

/// Hooks that let edit mode (Stage C) wrap rendered nodes with drag handles /
/// drop zones without changing the renderer. The base class is a no-op, so
/// normal app rendering is unaffected.
abstract class RenderHooks {
  const RenderHooks();

  /// Whether edit affordances are active (selection, drag, drop zones).
  bool get active => false;

  /// Wrap a fully-rendered node. [parent] is the container it sits in (null for
  /// the root). Edit mode adds a selection outline + drag/pan handling here.
  Widget decorate(BuildContext context, LayoutNode node, ContainerNode? parent, Widget child) =>
      child;

  /// Assemble the children of a flow container into the final widget list.
  /// Default: insert `gap` spacers and wrap row leaves in [Expanded]. Edit mode
  /// overrides this to weave in drop targets.
  List<Widget> assembleFlow(BuildContext context, ContainerNode parent, Axis axis,
      List<LayoutNode> nodes, List<Widget> widgets) {
    final gap = parent.props.gap ?? 0;
    final expand = parent.props.expandChildren ?? true;
    final out = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      if (i > 0 && gap > 0) {
        out.add(axis == Axis.vertical ? SizedBox(height: gap) : SizedBox(width: gap));
      }
      out.add(axis == Axis.horizontal && expand && nodes[i] is! ContainerNode
          ? Expanded(child: widgets[i])
          : widgets[i]);
    }
    return out;
  }

  /// Wrap a free-mode container's Stack (edit mode adds a drop surface).
  Widget decorateFreeSurface(BuildContext context, ContainerNode parent, Widget stack) => stack;
}

class _NoopHooks extends RenderHooks {
  const _NoopHooks();
}

/// Renders a [LayoutNode] tree into Flutter widgets, resolving leaf `ref`s
/// through the [NodeRegistry]. Pure and recursive; see LAYOUT_MODEL.md.
class LayoutTreeRenderer {
  LayoutTreeRenderer({required this.registry, RenderHooks? hooks, this.reporter})
      : hooks = hooks ?? const _NoopHooks();

  final NodeRegistry registry;
  final RenderHooks hooks;

  /// Data context for `{{bindings}}` and `when` conditions. Updated by RemoteUI
  /// from the synced [LayoutState.data] before each build.
  Map<String, dynamic> data = const {};

  /// When set (edit mode + web), each node reports its rect for the dashboard
  /// overlay. Null everywhere else, so there's zero overhead off the editor.
  final GeometryReporter? reporter;

  Widget build(BuildContext context, LayoutNode node, [ContainerNode? parent]) {
    if (!node.visible) return const SizedBox.shrink();
    // A `when` condition that resolves false hides the node in production. In
    // edit mode we keep it visible-but-dimmed so it stays selectable.
    final conditionHidden = node.when != null && !Binding.evalCondition(node.when, data);
    if (conditionHidden && !hooks.active) return const SizedBox.shrink();
    final widget = switch (node) {
      LeafNode leaf => _buildLeaf(context, leaf),
      TextNode t => _buildText(context, t),
      PrimitiveNode p => _buildPrimitive(context, p),
      ContainerNode c => _buildContainer(context, c),
    };
    final styled = _applyStyle(node.style, widget);
    final decorated = hooks.decorate(context, node, parent, styled);
    // In-place pixel offset: translates the node without changing its layout
    // slot, so siblings stay put.
    final o = node.offset;
    Widget out = decorated;
    if (o != null && !o.isZero) {
      out = Transform.translate(offset: Offset(o.dx, o.dy), transformHitTests: true, child: decorated);
    }
    final a = node.animation;
    if (a != null && !a.isNone) {
      out = _AnimatedNode(key: ValueKey('anim_${node.id}'), anim: a, child: out);
    }
    // Edit mode: a condition that's currently false → dim so the editor shows it
    // would be hidden, while keeping it selectable/draggable.
    if (conditionHidden) {
      out = Opacity(opacity: 0.35, child: out);
    }
    if (reporter != null) {
      out = _GeometryProbe(key: ValueKey('probe_${node.id}'), id: node.id, reporter: reporter!, child: out);
    }
    return out;
  }

  // Wrap a node with its visual style overlay (background, radius, padding,
  // margin, and inherited typography/colors).
  Widget _applyStyle(NodeStyle? style, Widget child) {
    if (style == null || style.isEmpty) return child;
    Widget out = child;

    final bg = _color(style.background);
    final radius = style.radius;
    final pad = style.padding;
    if (bg != null || radius != null || pad != null) {
      out = Container(
        padding: pad != null ? EdgeInsets.all(pad) : null,
        clipBehavior: radius != null ? Clip.antiAlias : Clip.none,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius != null ? BorderRadius.circular(radius) : null,
        ),
        child: out,
      );
    }
    if (style.margin != null) {
      out = Padding(padding: EdgeInsets.all(style.margin!), child: out);
    }

    final ts = _textStyle(style);
    if (ts != null) {
      out = DefaultTextStyle.merge(style: ts, child: out);
      final tc = _color(style.textColor);
      if (tc != null) out = IconTheme.merge(data: IconThemeData(color: tc), child: out);
    }
    // Explicit size (null axis = auto). Goes outermost so it sizes everything.
    if (style.width != null || style.height != null) {
      out = SizedBox(width: style.width, height: style.height, child: out);
    }
    return out;
  }

  static TextStyle? _textStyle(NodeStyle s) {
    if (s.textColor == null && s.fontSize == null && s.fontWeight == null && s.letterSpacing == null) {
      return null;
    }
    return TextStyle(
      color: _color(s.textColor),
      fontSize: s.fontSize,
      fontWeight: _weight(s.fontWeight),
      letterSpacing: s.letterSpacing,
    );
  }

  static FontWeight? _weight(String? w) => switch (w) {
        'w100' => FontWeight.w100,
        'w200' => FontWeight.w200,
        'w300' => FontWeight.w300,
        'normal' => FontWeight.w400,
        'w500' => FontWeight.w500,
        'w600' => FontWeight.w600,
        'bold' => FontWeight.w700,
        'w800' => FontWeight.w800,
        'w900' => FontWeight.w900,
        _ => null,
      };

  // Parse "#RGB", "#RRGGBB", or "#AARRGGBB" into a Color.
  static Color? _color(String? hex) {
    if (hex == null) return null;
    var h = hex.replaceFirst('#', '');
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join(); // #RGB -> #RRGGBB
    if (h.length == 6) h = 'FF$h'; // add opaque alpha
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }

  Widget _buildLeaf(BuildContext context, LeafNode leaf) {
    return registry[leaf.ref] ?? const SizedBox.shrink();
  }

  Widget _buildText(BuildContext context, TextNode node) {
    // Resolve {{bindings}} against the data context, then fall back to a
    // placeholder while editing if the result is empty.
    final resolved = Binding.interpolate(node.text, data);
    final content = resolved.isEmpty && hooks.active ? 'Text' : resolved;
    return Text(content);
  }

  Widget _buildPrimitive(BuildContext context, PrimitiveNode p) {
    final d = p.data;
    switch (p.prim) {
      case 'button':
        return FilledButton(
          onPressed: () {},
          child: Text(Binding.interpolate((d['text'] as String?) ?? 'Button', data)),
        );
      case 'divider':
        final th = (d['thickness'] as num?)?.toDouble() ?? 1;
        return Divider(thickness: th, height: th + 16);
      case 'spacer':
        final sz = (d['size'] as num?)?.toDouble() ?? 16;
        return SizedBox(height: sz, width: sz);
      case 'icon':
        return Icon(_iconFor((d['icon'] as String?) ?? 'star'),
            size: (d['size'] as num?)?.toDouble() ?? 28);
      case 'image':
        final url = (d['url'] as String?) ?? '';
        final h = (d['height'] as num?)?.toDouble() ?? 160;
        if (url.isEmpty) return _imagePlaceholder(h);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(url, height: h, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _imagePlaceholder(h)),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _imagePlaceholder(double h) => Container(
        height: h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_outlined, color: Color(0x66FFFFFF), size: 32),
      );

  static IconData _iconFor(String name) => switch (name) {
        'home' => Icons.home_rounded,
        'heart' => Icons.favorite_rounded,
        'search' => Icons.search_rounded,
        'settings' => Icons.settings_rounded,
        'add' => Icons.add_rounded,
        'check' => Icons.check_rounded,
        'arrow' => Icons.arrow_forward_rounded,
        'menu' => Icons.menu_rounded,
        'person' => Icons.person_rounded,
        'play' => Icons.play_arrow_rounded,
        'cart' => Icons.shopping_cart_rounded,
        'bell' => Icons.notifications_rounded,
        'music' => Icons.music_note_rounded,
        'camera' => Icons.camera_alt_rounded,
        _ => Icons.star_rounded,
      };

  Widget _buildContainer(BuildContext context, ContainerNode c) {
    final visibleChildren = c.children.where((n) => n.visible).toList();
    final padding = c.props.padding ?? 0;
    Widget body;

    // In the editor, an empty container is given a visible, targetable area so
    // you can drop widgets INTO it. End users never see this (hooks inactive).
    if (hooks.active && visibleChildren.isEmpty) {
      body = _emptyDropHint(c.type.name);
    } else if (c.mode == ContainerMode.free) {
      body = _buildFree(context, c, visibleChildren);
    } else {
      body = switch (c.type) {
        ContainerType.column => _buildAxis(context, c, visibleChildren, Axis.vertical),
        ContainerType.row => _buildAxis(context, c, visibleChildren, Axis.horizontal),
        ContainerType.grid => _buildGrid(context, c, visibleChildren),
        ContainerType.stack =>
          Stack(children: [for (final n in visibleChildren) build(context, n, c)]),
      };
    }
    if (padding > 0) body = Padding(padding: EdgeInsets.all(padding), child: body);
    return body;
  }

  Widget _emptyDropHint(String label) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x553B82F6)),
        borderRadius: BorderRadius.circular(6),
        color: const Color(0x113B82F6),
      ),
      child: Text('empty $label · drop here',
          style: const TextStyle(fontSize: 10, color: Color(0xAA3B82F6))),
    );
  }

  Widget _buildAxis(BuildContext context, ContainerNode c, List<LayoutNode> children, Axis axis) {
    final widgets = [for (final n in children) build(context, n, c)];
    final assembled = hooks.assembleFlow(context, c, axis, children, widgets);
    final main = _mainAxis(c.props.mainAxis);
    final cross = _crossAxis(c.props.crossAxis);
    return axis == Axis.vertical
        ? Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: main, crossAxisAlignment: cross, children: assembled)
        : Row(mainAxisAlignment: main, crossAxisAlignment: cross, children: assembled);
  }

  Widget _buildGrid(BuildContext context, ContainerNode c, List<LayoutNode> children) {
    final cols = (c.props.crossAxisCount ?? 2).clamp(1, 6);
    final gap = c.props.gap ?? 8;
    return LayoutBuilder(builder: (context, constraints) {
      final itemW = (constraints.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final n in children)
            SizedBox(width: itemW.isFinite ? itemW : null, child: build(context, n, c)),
        ],
      );
    });
  }

  Widget _buildFree(BuildContext context, ContainerNode c, List<LayoutNode> children) {
    double maxBottom = 0;
    for (final n in children) {
      final f = n.frame;
      if (f != null) {
        final b = f.top + (f.height ?? 140);
        if (b > maxBottom) maxBottom = b;
      }
    }
    final stack = Stack(
      children: [
        for (final n in children)
          Positioned(
            left: n.frame?.left ?? 0,
            top: n.frame?.top ?? 0,
            width: n.frame?.width,
            height: n.frame?.height,
            child: n.frame?.width == null
                ? IntrinsicWidth(child: build(context, n, c))
                : build(context, n, c),
          ),
      ],
    );
    return SizedBox(
      height: maxBottom > 0 ? maxBottom + 16 : 160,
      child: hooks.decorateFreeSurface(context, c, stack),
    );
  }

  static MainAxisAlignment _mainAxis(String? v) => switch (v) {
        'center' => MainAxisAlignment.center,
        'end' => MainAxisAlignment.end,
        'spaceBetween' => MainAxisAlignment.spaceBetween,
        'spaceAround' => MainAxisAlignment.spaceAround,
        _ => MainAxisAlignment.start,
      };

  static CrossAxisAlignment _crossAxis(String? v) => switch (v) {
        'center' => CrossAxisAlignment.center,
        'end' => CrossAxisAlignment.end,
        'stretch' => CrossAxisAlignment.stretch,
        _ => CrossAxisAlignment.start,
      };
}

/// Plays an entrance animation for a node and REPLAYS whenever the config (or
/// playId) changes — so editor tweaks preview live.
class _AnimatedNode extends StatefulWidget {
  const _AnimatedNode({required this.anim, required this.child, super.key});
  final NodeAnimation anim;
  final Widget child;

  @override
  State<_AnimatedNode> createState() => _AnimatedNodeState();
}

class _AnimatedNodeState extends State<_AnimatedNode> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.anim.duration);

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void didUpdateWidget(covariant _AnimatedNode old) {
    super.didUpdateWidget(old);
    final a = widget.anim, b = old.anim;
    if (a.type != b.type || a.durationMs != b.durationMs || a.curve != b.curve ||
        a.delayMs != b.delayMs || a.playId != b.playId) {
      _play();
    }
  }

  void _play() {
    _c.duration = widget.anim.duration;
    _c.value = 0;
    if (widget.anim.delayMs > 0) {
      Future.delayed(widget.anim.delay, () {
        if (mounted) _c.forward(from: 0);
      });
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = _curve(widget.anim.curve);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = curve.transform(_c.value.clamp(0.0, 1.0));
        switch (widget.anim.type) {
          case 'fade':
            return Opacity(opacity: t, child: child);
          case 'slideUp':
            return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 28), child: child));
          case 'slideDown':
            return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, -(1 - t) * 28), child: child));
          case 'slideLeft':
            return Opacity(opacity: t, child: Transform.translate(offset: Offset((1 - t) * 28, 0), child: child));
          case 'slideRight':
            return Opacity(opacity: t, child: Transform.translate(offset: Offset(-(1 - t) * 28, 0), child: child));
          case 'scale':
            return Opacity(opacity: t, child: Transform.scale(scale: 0.85 + 0.15 * t, child: child));
          case 'rotate':
            return Opacity(opacity: t, child: Transform.rotate(angle: (1 - t) * 0.18, child: child));
          default:
            return child!;
        }
      },
    );
  }

  static Curve _curve(String name) => switch (name) {
        'linear' => Curves.linear,
        'easeIn' => Curves.easeIn,
        'easeInOut' => Curves.easeInOut,
        'fastOutSlowIn' => Curves.fastOutSlowIn,
        'decelerate' => Curves.decelerate,
        'bounceOut' => Curves.bounceOut,
        'elasticOut' => Curves.elasticOut,
        _ => Curves.easeOut,
      };
}

/// Reports its child's on-screen rect to the [GeometryReporter] after each
/// frame, so the dashboard can position drop targets over the simulator.
class _GeometryProbe extends StatefulWidget {
  const _GeometryProbe({required this.id, required this.reporter, required this.child, super.key});
  final String id;
  final GeometryReporter reporter;
  final Widget child;

  @override
  State<_GeometryProbe> createState() => _GeometryProbeState();
}

class _GeometryProbeState extends State<_GeometryProbe> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ro = context.findRenderObject();
      if (ro is RenderBox && ro.attached && ro.hasSize) {
        widget.reporter.report(widget.id, ro.localToGlobal(Offset.zero) & ro.size);
      }
    });
    return widget.child;
  }
}
