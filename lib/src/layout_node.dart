import 'package:flutter/foundation.dart';

/// Absolute placement of a node when its parent container is in `free` mode.
@immutable
class Frame {
  const Frame({required this.left, required this.top, this.width, this.height});

  final double left;
  final double top;
  final double? width;
  final double? height;

  factory Frame.fromJson(Map<String, dynamic> j) => Frame(
        left: (j['left'] as num?)?.toDouble() ?? 0,
        top: (j['top'] as num?)?.toDouble() ?? 0,
        width: (j['width'] as num?)?.toDouble(),
        height: (j['height'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'left': left,
        'top': top,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      };

  Frame copyWith({double? left, double? top, double? width, double? height}) =>
      Frame(left: left ?? this.left, top: top ?? this.top, width: width ?? this.width, height: height ?? this.height);
}

/// Visual style overlay applied around any node (leaf or container). All
/// fields optional; colors are `#RRGGBB` or `#AARRGGBB` hex strings.
@immutable
class NodeStyle {
  const NodeStyle({
    this.background,
    this.textColor,
    this.fontSize,
    this.fontWeight,
    this.letterSpacing,
    this.radius,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  final String? background;
  final String? textColor;
  final double? fontSize;
  final String? fontWeight; // w100..w900 | normal | bold
  final double? letterSpacing;
  final double? radius;
  final double? padding;
  final double? margin;
  final double? width;
  final double? height;

  bool get isEmpty =>
      background == null &&
      textColor == null &&
      fontSize == null &&
      fontWeight == null &&
      letterSpacing == null &&
      radius == null &&
      padding == null &&
      margin == null &&
      width == null &&
      height == null;

  factory NodeStyle.fromJson(Map<String, dynamic> j) => NodeStyle(
        background: j['background'] as String?,
        textColor: j['textColor'] as String?,
        fontSize: (j['fontSize'] as num?)?.toDouble(),
        fontWeight: j['fontWeight'] as String?,
        letterSpacing: (j['letterSpacing'] as num?)?.toDouble(),
        radius: (j['radius'] as num?)?.toDouble(),
        padding: (j['padding'] as num?)?.toDouble(),
        margin: (j['margin'] as num?)?.toDouble(),
        width: (j['width'] as num?)?.toDouble(),
        height: (j['height'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        if (background != null) 'background': background,
        if (textColor != null) 'textColor': textColor,
        if (fontSize != null) 'fontSize': fontSize,
        if (fontWeight != null) 'fontWeight': fontWeight,
        if (letterSpacing != null) 'letterSpacing': letterSpacing,
        if (radius != null) 'radius': radius,
        if (padding != null) 'padding': padding,
        if (margin != null) 'margin': margin,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      };
}

/// A pixel translate applied to a node WITHOUT changing the layout — the node
/// keeps its slot, so siblings don't move. Use for in-place fine positioning.
@immutable
class NodeOffset {
  const NodeOffset({this.dx = 0, this.dy = 0});
  final double dx;
  final double dy;

  bool get isZero => dx == 0 && dy == 0;

  factory NodeOffset.fromJson(Map<String, dynamic> j) => NodeOffset(
        dx: (j['dx'] as num?)?.toDouble() ?? 0,
        dy: (j['dy'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'dx': dx, 'dy': dy};
}

/// Animation config for a node. Plays as an entrance animation when the node
/// appears, and replays whenever the config (or [playId]) changes — so the
/// editor can preview changes live.
@immutable
class NodeAnimation {
  const NodeAnimation({
    this.type = 'none',
    this.durationMs = 350,
    this.curve = 'easeOut',
    this.delayMs = 0,
    this.playId = 0,
  });

  /// none | fade | slideUp | slideDown | slideLeft | slideRight | scale | rotate
  final String type;
  final int durationMs;
  final String curve;
  final int delayMs;

  /// Bump to force a replay without otherwise changing the config.
  final int playId;

  bool get isNone => type == 'none';
  Duration get duration => Duration(milliseconds: durationMs);
  Duration get delay => Duration(milliseconds: delayMs);

  factory NodeAnimation.fromJson(Map<String, dynamic> j) => NodeAnimation(
        type: j['type'] as String? ?? 'none',
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 350,
        curve: j['curve'] as String? ?? 'easeOut',
        delayMs: (j['delayMs'] as num?)?.toInt() ?? 0,
        playId: (j['playId'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'durationMs': durationMs,
        'curve': curve,
        if (delayMs != 0) 'delayMs': delayMs,
        if (playId != 0) 'playId': playId,
      };
}

enum ContainerType { column, row, grid, stack }

enum ContainerMode { flow, free }

/// Container layout properties (see LAYOUT_MODEL.md).
@immutable
class ContainerProps {
  const ContainerProps({
    this.gap,
    this.padding,
    this.mainAxis,
    this.crossAxis,
    this.crossAxisCount,
    this.expandChildren,
  });

  final double? gap;
  final double? padding;
  final String? mainAxis; // start|center|end|spaceBetween|spaceAround
  final String? crossAxis; // start|center|end|stretch
  final int? crossAxisCount;

  /// In a row, whether leaf children stretch to share width ([Expanded]) or keep
  /// their intrinsic size. Defaults to true (good for cards; false for toolbars).
  final bool? expandChildren;

  factory ContainerProps.fromJson(Map<String, dynamic> j) => ContainerProps(
        gap: (j['gap'] as num?)?.toDouble(),
        padding: (j['padding'] as num?)?.toDouble(),
        mainAxis: j['mainAxis'] as String?,
        crossAxis: j['crossAxis'] as String?,
        crossAxisCount: (j['crossAxisCount'] as num?)?.toInt(),
        expandChildren: j['expandChildren'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        if (gap != null) 'gap': gap,
        if (padding != null) 'padding': padding,
        if (mainAxis != null) 'mainAxis': mainAxis,
        if (crossAxis != null) 'crossAxis': crossAxis,
        if (crossAxisCount != null) 'crossAxisCount': crossAxisCount,
        if (expandChildren != null) 'expandChildren': expandChildren,
      };
}

/// A node in the layout tree: either a [LeafNode] (references a registered
/// widget) or a [ContainerNode] (arranges other nodes).
@immutable
sealed class LayoutNode {
  const LayoutNode({required this.id, this.visible = true, this.when, this.frame, this.style, this.offset, this.animation});

  final String id;
  final bool visible;

  /// Optional visibility condition resolved against the data context, e.g.
  /// `cart.count > 0`. When it evaluates false the node is hidden (production)
  /// or dimmed (edit mode). Null/empty = always visible.
  final String? when;

  final Frame? frame;
  final NodeStyle? style;
  final NodeOffset? offset;
  final NodeAnimation? animation;

  Map<String, dynamic> toJson();

  static LayoutNode fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String? ?? 'node';
    final visible = j['visible'] != false;
    final when = (j['when'] as String?)?.trim();
    final w = (when == null || when.isEmpty) ? null : when;
    final frame = j['frame'] is Map ? Frame.fromJson(Map<String, dynamic>.from(j['frame'])) : null;
    final style = j['style'] is Map ? NodeStyle.fromJson(Map<String, dynamic>.from(j['style'])) : null;
    final offset = j['offset'] is Map ? NodeOffset.fromJson(Map<String, dynamic>.from(j['offset'])) : null;
    final animation = j['animation'] is Map ? NodeAnimation.fromJson(Map<String, dynamic>.from(j['animation'])) : null;
    if (j['kind'] == 'leaf') {
      return LeafNode(id: id, ref: j['ref'] as String? ?? '', visible: visible, when: w, frame: frame, style: style, offset: offset, animation: animation);
    }
    if (j['kind'] == 'text') {
      return TextNode(id: id, text: j['text'] as String? ?? '', visible: visible, when: w, frame: frame, style: style, offset: offset, animation: animation);
    }
    if (kPrimitiveKinds.contains(j['kind'])) {
      const reserved = {'id', 'kind', 'visible', 'when', 'frame', 'style', 'offset', 'animation'};
      final data = {for (final e in j.entries) if (!reserved.contains(e.key)) e.key: e.value};
      return PrimitiveNode(
        id: id, prim: j['kind'] as String, data: data,
        visible: visible, when: w, frame: frame, style: style, offset: offset, animation: animation,
      );
    }
    return ContainerNode(
      id: id,
      type: _typeFrom(j['type']),
      mode: j['mode'] == 'free' ? ContainerMode.free : ContainerMode.flow,
      props: j['props'] is Map ? ContainerProps.fromJson(Map<String, dynamic>.from(j['props'])) : const ContainerProps(),
      children: (j['children'] as List? ?? const [])
          .map((c) => LayoutNode.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
      visible: visible,
      when: w,
      frame: frame,
      style: style,
      offset: offset,
      animation: animation,
    );
  }

  static ContainerType _typeFrom(Object? v) => switch (v) {
        'row' => ContainerType.row,
        'grid' => ContainerType.grid,
        'stack' => ContainerType.stack,
        _ => ContainerType.column,
      };
}

class LeafNode extends LayoutNode {
  const LeafNode({required super.id, required this.ref, super.visible, super.when, super.frame, super.style, super.offset, super.animation});

  final String ref;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': 'leaf',
        'ref': ref,
        if (!visible) 'visible': false,
        if (when != null) 'when': when,
        if (frame != null) 'frame': frame!.toJson(),
        if (style != null) 'style': style!.toJson(),
        if (offset != null) 'offset': offset!.toJson(),
        if (animation != null) 'animation': animation!.toJson(),
      };
}

/// A text node whose content + style live entirely in the layout graph, so it
/// can be added and edited from the editor with no Dart changes.
class TextNode extends LayoutNode {
  const TextNode({required super.id, required this.text, super.visible, super.when, super.frame, super.style, super.offset, super.animation});

  final String text;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': 'text',
        'text': text,
        if (!visible) 'visible': false,
        if (when != null) 'when': when,
        if (frame != null) 'frame': frame!.toJson(),
        if (style != null) 'style': style!.toJson(),
        if (offset != null) 'offset': offset!.toJson(),
        if (animation != null) 'animation': animation!.toJson(),
      };
}

/// Built-in primitive widgets the SDK renders straight from the graph — no
/// developer registration. `prim` is one of [kPrimitiveKinds]; [data] holds its
/// config (e.g. text for a button, size for a spacer).
const kPrimitiveKinds = {'button', 'divider', 'spacer', 'icon', 'image'};

class PrimitiveNode extends LayoutNode {
  const PrimitiveNode({
    required super.id,
    required this.prim,
    this.data = const {},
    super.visible,
    super.when,
    super.frame,
    super.style,
    super.offset,
    super.animation,
  });

  final String prim;
  final Map<String, dynamic> data;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': prim,
        ...data,
        if (!visible) 'visible': false,
        if (when != null) 'when': when,
        if (frame != null) 'frame': frame!.toJson(),
        if (style != null) 'style': style!.toJson(),
        if (offset != null) 'offset': offset!.toJson(),
        if (animation != null) 'animation': animation!.toJson(),
      };
}

class ContainerNode extends LayoutNode {
  const ContainerNode({
    required super.id,
    required this.type,
    required this.children,
    this.mode = ContainerMode.flow,
    this.props = const ContainerProps(),
    super.visible,
    super.when,
    super.frame,
    super.style,
    super.offset,
    super.animation,
  });

  final ContainerType type;
  final ContainerMode mode;
  final ContainerProps props;
  final List<LayoutNode> children;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': 'container',
        'type': type.name,
        'mode': mode.name,
        'props': props.toJson(),
        if (!visible) 'visible': false,
        if (when != null) 'when': when,
        if (frame != null) 'frame': frame!.toJson(),
        if (style != null) 'style': style!.toJson(),
        if (offset != null) 'offset': offset!.toJson(),
        if (animation != null) 'animation': animation!.toJson(),
        'children': children.map((c) => c.toJson()).toList(),
      };
}
