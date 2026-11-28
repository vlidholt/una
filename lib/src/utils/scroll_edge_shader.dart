import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

// The soft scroll edge of a Liquid Glass bar where the renderer has no
// shader image filters (every browser). Internal.
//
// The package's graduated blur is a shader image filter, which only
// Impeller has. Without one, a graduated blur built from backdrop filters
// showed bands. This draws it as iOS does, in one pass: the page under the
// bar is snapshot at a third of its resolution and blurred in
// `shaders/scroll_edge.frag`, the sigma falling from the screen's edge to
// nothing, and the page colour laid over it.
//
// The snapshot is taken while the frame's scene is built, not while it is
// painted: by then everything under the bar has been painted this frame,
// whichever repaint boundaries were dirty. The page it is taken from is the
// one a `ScrollEdgeSource` marks — a `Scaffold` marks its body. A bar
// inside that page (a `SliverAppBar`) keeps itself out of the picture with
// a `ScrollEdgeExclusion`, or its own buttons would be blurred into its
// edge.
//
// Not for an edge inside the page it snapshots (a `SliverAppBar`'s): a
// snapshot taken while that page is halfway into the scene took its
// content out of the frames that followed, and an article vanished as its
// bar collapsed. That edge takes its snapshot after the frame and draws it
// in the next, asking for one more frame so that the page at rest is what
// it shows: a frame late, under a blur.

/// The fragment program, loaded once for the app.
abstract final class ScrollEdgeShader {
  static ui.FragmentProgram? _program;
  static Future<void>? _loading;

  /// The edges waiting for the program, repainted when it arrives.
  static final loaded = ValueNotifier<ui.FragmentProgram?>(null);

  /// The program, or null while it is loading or if it failed to load.
  static ui.FragmentProgram? get program => _program;

  /// Starts loading the program, once. In an app the shader is the
  /// package's asset; in this package's own tests it is its own.
  static Future<void> load() => _loading ??= () async {
    for (final key in const [
      'packages/una/shaders/scroll_edge.frag',
      'shaders/scroll_edge.frag',
    ]) {
      try {
        _program = await ui.FragmentProgram.fromAsset(key);
        loaded.value = _program;
        return;
      } on Object {
        // The next name, or none: the edge is then the veil alone.
      }
    }
  }();

  /// Texels of the snapshot per logical pixel. The edge is blurred by up to
  /// a dozen points, so a third of the resolution loses nothing the eye can
  /// see and makes the copy, and every tap of the kernel, cheap.
  static const texScale = 1 / 3;
}

/// Where a [ScrollEdgeSource] registers itself for the edges around it.
class ScrollEdgeSourceHandle {
  _RenderScrollEdgeSource? _render;
}

/// Hands the [ScrollEdgeSourceHandle] of a page to the bars over it and in
/// it.
class ScrollEdgeSourceScope extends InheritedWidget {
  /// Hands [handle] to [child].
  const ScrollEdgeSourceScope({
    required this.handle,
    required super.child,
    super.key,
  });

  /// The page's handle.
  final ScrollEdgeSourceHandle handle;

  /// The handle above [context], if any.
  static ScrollEdgeSourceHandle? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ScrollEdgeSourceScope>()
      ?.handle;

  @override
  bool updateShouldNotify(ScrollEdgeSourceScope oldWidget) =>
      !identical(handle, oldWidget.handle);
}

/// The page a scroll edge takes its snapshot from: a layer of its own,
/// registered with [handle].
class ScrollEdgeSource extends SingleChildRenderObjectWidget {
  /// Marks [child] as the page under the bars.
  const ScrollEdgeSource({
    required this.handle,
    required super.child,
    super.key,
  });

  /// Where the page registers itself.
  final ScrollEdgeSourceHandle handle;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderScrollEdgeSource(handle);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderScrollEdgeSource).handle = handle;
  }
}

class _RenderScrollEdgeSource extends RenderProxyBox {
  _RenderScrollEdgeSource(this._handle);

  ScrollEdgeSourceHandle get handle => _handle;
  ScrollEdgeSourceHandle _handle;
  set handle(ScrollEdgeSourceHandle value) {
    if (identical(value, _handle)) return;
    if (identical(_handle._render, this)) _handle._render = null;
    _handle = value;
    if (attached) _handle._render = this;
  }

  // A layer of its own, so the page can be snapshot on its own. It also
  // keeps the page from repainting with the bars laid over it.
  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _handle._render = this;
  }

  @override
  void detach() {
    if (identical(_handle._render, this)) _handle._render = null;
    super.detach();
  }

  /// [bounds] of the page, in its own coordinates, at [pixelRatio] texels
  /// per logical pixel; null before the page has a layer.
  ui.Image? snapshot(Rect bounds, double pixelRatio) {
    final layer = this.layer;
    if (layer is! OffsetLayer || !layer.attached) return null;
    return layer.toImageSync(bounds, pixelRatio: pixelRatio);
  }
}

/// Whether a scroll edge is taking its snapshot: the layers that must not
/// be in it (the edge itself, a bar inside the page) add nothing then.
bool _taking = false;

/// Keeps [child] out of the snapshot a scroll edge takes of the page it is
/// in, while [active]: a bar inside the page, whose own buttons and title
/// would otherwise be blurred into its edge.
class ScrollEdgeExclusion extends SingleChildRenderObjectWidget {
  /// Keeps [child] out of the edge's snapshot while [active].
  const ScrollEdgeExclusion({
    required this.active,
    required super.child,
    super.key,
  });

  /// Whether a shader edge may be taking snapshots of the page.
  final bool active;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderScrollEdgeExclusion(active);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderScrollEdgeExclusion).active = active;
  }
}

class _RenderScrollEdgeExclusion extends RenderProxyBox {
  _RenderScrollEdgeExclusion(this._active);

  bool get active => _active;
  bool _active;
  set active(bool value) {
    if (value == _active) return;
    _active = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _active;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_active) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    final exclusion = (layer as _ExclusionLayer?) ?? _ExclusionLayer();
    layer = exclusion;
    context.pushLayer(exclusion, super.paint, offset);
  }
}

class _ExclusionLayer extends OffsetLayer {
  // Asked every frame, so that a snapshot never takes it from the last.
  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    if (_taking) return;
    super.addToScene(builder);
  }
}

/// The scroll edge drawn with una's shader: the page under the box,
/// blurred by up to [maxSigma] at the screen's edge and faded into
/// [color]. Without a page to take it from, or before the shader has
/// loaded, the veil of [color] alone.
class ShaderScrollEdge extends LeafRenderObjectWidget {
  /// Creates the edge.
  const ShaderScrollEdge({
    required this.color,
    required this.maxSigma,
    required this.strength,
    required this.fromBottom,
    super.key,
  });

  /// The page colour the content fades into.
  final Color color;

  /// The sigma at the screen's edge at full [strength].
  final double maxSigma;

  /// How much of the edge shows, from 0 to 1: the blur's strength and the
  /// veil's opacity.
  final double strength;

  /// Whether the screen's edge is at the bottom of the box.
  final bool fromBottom;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderShaderScrollEdge(
        handle: ScrollEdgeSourceScope.maybeOf(context),
        color: color,
        maxSigma: maxSigma,
        strength: strength,
        fromBottom: fromBottom,
      );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderShaderScrollEdge)
      ..handle = ScrollEdgeSourceScope.maybeOf(context)
      ..color = color
      ..maxSigma = maxSigma
      ..strength = strength
      ..fromBottom = fromBottom;
  }
}

class _RenderShaderScrollEdge extends RenderBox {
  _RenderShaderScrollEdge({
    required this.handle,
    required Color color,
    required double maxSigma,
    required double strength,
    required bool fromBottom,
  }) : _color = color,
       _maxSigma = maxSigma,
       _strength = strength,
       _fromBottom = fromBottom;

  ScrollEdgeSourceHandle? handle;

  Color get color => _color;
  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  double get maxSigma => _maxSigma;
  double _maxSigma;
  set maxSigma(double value) {
    if (value == _maxSigma) return;
    _maxSigma = value;
    markNeedsPaint();
  }

  double get strength => _strength;
  double _strength;
  set strength(double value) {
    if (value == _strength) return;
    _strength = value;
    markNeedsPaint();
  }

  bool get fromBottom => _fromBottom;
  bool _fromBottom;
  set fromBottom(bool value) {
    if (value == _fromBottom) return;
    _fromBottom = value;
    markNeedsPaint();
  }

  final _layer = LayerHandle<_ScrollEdgeLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (ScrollEdgeShader.program == null) {
      ScrollEdgeShader.loaded.addListener(markNeedsPaint);
      unawaited(ScrollEdgeShader.load());
    }
  }

  @override
  void detach() {
    ScrollEdgeShader.loaded.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  // A layer every frame the edge shows: it is what takes the snapshot.
  @override
  bool get alwaysNeedsCompositing => true;

  /// Whether this edge is inside the page it snapshots.
  bool _isInside(RenderObject source) {
    var node = parent;
    while (node != null) {
      if (identical(node, source)) return true;
      node = node.parent;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_strength <= 0 || size.isEmpty) {
      _layer.layer = null;
      return;
    }
    final source = handle?._render;
    Rect? region;
    if (source != null && source.attached && attached) {
      region = MatrixUtils.transformRect(
        getTransformTo(source),
        Offset.zero & size,
      );
    }
    final layer = _layer.layer ??= _ScrollEdgeLayer();
    layer
      ..rect = offset & size
      ..source = source
      ..deferred = source != null && _isInside(source)
      ..region = region
      ..color = _color
      ..sigma = _maxSigma * _strength
      ..veilAlpha = _strength
      ..fromBottom = _fromBottom;
    context.addLayer(layer);
  }
}

class _ScrollEdgeLayer extends Layer {
  Rect rect = Rect.zero;
  _RenderScrollEdgeSource? source;
  Rect? region;
  Color color = const Color(0x00000000);
  double sigma = 0;
  double veilAlpha = 0;
  bool fromBottom = false;

  /// Whether the snapshot is taken after the frame rather than while the
  /// scene is built: the edge is inside the page it snapshots.
  bool deferred = false;

  ui.FragmentShader? _shader;
  ui.Image? _image;
  ui.Picture? _picture;

  /// A deferred edge's snapshot, taken after the last frame, for the next.
  ui.Image? _next;
  bool _snapshotScheduled = false;
  bool _followUp = false;

  void _snapshotAfterFrame() {
    if (_snapshotScheduled) return;
    _snapshotScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _snapshotScheduled = false;
      final source = this.source;
      final region = this.region;
      if (!attached ||
          source == null ||
          !source.attached ||
          region == null ||
          region.isEmpty) {
        return;
      }
      ui.Image? image;
      _taking = true;
      try {
        image = source.snapshot(region, ScrollEdgeShader.texScale);
      } finally {
        _taking = false;
      }
      if (image == null) return;
      _next?.dispose();
      _next = image;
      // One more frame to show it: the page may have moved in the frame
      // just drawn. Not after a frame that was only that, or it would
      // never stop.
      if (_followUp) {
        _followUp = false;
      } else {
        _followUp = true;
        SchedulerBinding.instance.scheduleFrame();
      }
    });
  }

  // Drawn anew every frame: the page under it may have moved without the
  // edge being painted again.
  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    if (_taking) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final program = ScrollEdgeShader.program;
    final source = this.source;
    final region = this.region;
    ui.Image? image;
    final ready =
        program != null &&
        source != null &&
        source.attached &&
        region != null &&
        !region.isEmpty &&
        sigma > 0;
    if (ready && deferred) {
      // Last frame's snapshot, or the one shown until a newer is taken.
      image = _next ?? _image;
      _next = null;
      _snapshotAfterFrame();
    } else if (ready) {
      _taking = true;
      try {
        image = source.snapshot(region, ScrollEdgeShader.texScale);
      } finally {
        _taking = false;
      }
    }
    if (image != null) {
      final shader = _shader ??= program!.fragmentShader();
      shader
        ..setFloat(0, rect.left)
        ..setFloat(1, rect.top)
        ..setFloat(2, rect.width)
        ..setFloat(3, rect.height)
        ..setFloat(4, sigma)
        ..setFloat(5, ScrollEdgeShader.texScale)
        ..setFloat(6, fromBottom ? 1 : 0)
        // The page colour, premultiplied, opaque: the snapshot holds the
        // page's content, not the background it is painted on.
        ..setFloat(7, color.r)
        ..setFloat(8, color.g)
        ..setFloat(9, color.b)
        ..setFloat(10, 1)
        ..setImageSampler(0, image);
      canvas.drawRect(rect, Paint()..shader = shader);
    }

    // The page colour over it, eased so the fade has no knee where it ends.
    final a = color.a * veilAlpha;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          fromBottom ? rect.bottomCenter : rect.topCenter,
          fromBottom ? rect.topCenter : rect.bottomCenter,
          [
            color.withValues(alpha: a * .8),
            color.withValues(alpha: a * .5),
            color.withValues(alpha: a * .15),
            color.withValues(alpha: 0),
          ],
          const [0, .4, .75, 1],
        ),
    );

    final picture = recorder.endRecording();
    builder.addPicture(Offset.zero, picture);
    // Last frame's are no longer drawn — unless a deferred edge showed the
    // same snapshot again.
    _picture?.dispose();
    if (!identical(_image, image)) _image?.dispose();
    _picture = picture;
    _image = image;
  }

  @override
  void dispose() {
    _picture?.dispose();
    _image?.dispose();
    _next?.dispose();
    _next = null;
    _shader?.dispose();
    _picture = null;
    _image = null;
    _shader = null;
    super.dispose();
  }
}
