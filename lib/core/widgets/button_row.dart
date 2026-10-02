// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';

/// Buttons side by side at equal widths, or stacked full width when any
/// label wouldn't fit its share (a long label or a large system font), so
/// labels are never cut short.
///
/// Stacked, the last child goes on top when [mainLast] (Cancel first, the
/// action last: the action leads).
class ButtonRow extends MultiChildRenderObjectWidget {
  const ButtonRow({
    super.key,
    required super.children,
    this.spacing = AppSpacing.s3,
    this.mainLast = true,
  });

  final double spacing;
  final bool mainLast;

  @override
  RenderButtonRow createRenderObject(BuildContext context) =>
      RenderButtonRow(spacing: spacing, mainLast: mainLast);

  @override
  void updateRenderObject(BuildContext context, RenderButtonRow renderObject) {
    renderObject
      ..spacing = spacing
      ..mainLast = mainLast;
  }
}

class _ButtonRowParentData extends ContainerBoxParentData<RenderBox> {}

class RenderButtonRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ButtonRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ButtonRowParentData> {
  RenderButtonRow({required double spacing, required bool mainLast})
    : _spacing = spacing,
      _mainLast = mainLast;

  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  bool _mainLast;
  set mainLast(bool value) {
    if (value == _mainLast) return;
    _mainLast = value;
    markNeedsLayout();
  }

  /// Whether the last layout stacked the buttons (for tests).
  bool get stacked => _stacked;
  bool _stacked = false;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ButtonRowParentData) child.parentData = _ButtonRowParentData();
  }

  List<RenderBox> get _children {
    final out = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      out.add(child);
      child = childAfter(child);
    }
    return out;
  }

  double _gaps(int count) => _spacing * math.max(0, count - 1);

  /// True when every child fits its equal share of [width].
  bool _fitsSideBySide(List<RenderBox> children, double width) {
    if (children.length < 2 || !width.isFinite) return true;
    final share = (width - _gaps(children.length)) / children.length;
    return children.every((c) => c.getMaxIntrinsicWidth(double.infinity) <= share + 0.5);
  }

  Size _layout(BoxConstraints constraints, ChildLayouter layoutChild, {required bool place}) {
    final children = _children;
    if (children.isEmpty) return constraints.smallest;
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : children.fold(0.0, (sum, c) => sum + c.getMaxIntrinsicWidth(double.infinity)) +
              _gaps(children.length);
    final sideBySide = _fitsSideBySide(children, width);
    if (place) _stacked = !sideBySide;

    if (sideBySide) {
      final share = (width - _gaps(children.length)) / children.length;
      final sizes = [
        for (final c in children) layoutChild(c, BoxConstraints.tightFor(width: share)),
      ];
      final height = sizes.fold(0.0, (h, s) => math.max(h, s.height));
      if (place) {
        for (var i = 0; i < children.length; i++) {
          (children[i].parentData! as _ButtonRowParentData).offset = Offset(
            i * (share + _spacing),
            (height - sizes[i].height) / 2,
          );
        }
      }
      return constraints.constrain(Size(width, height));
    }

    final ordered = _mainLast ? children.reversed.toList() : children;
    var y = 0.0;
    for (final c in ordered) {
      final size = layoutChild(c, BoxConstraints.tightFor(width: width));
      if (place) (c.parentData! as _ButtonRowParentData).offset = Offset(0, y);
      y += size.height + _spacing;
    }
    return constraints.constrain(Size(width, y - _spacing));
  }

  @override
  void performLayout() {
    size = _layout(constraints, ChildLayoutHelper.layoutChild, place: true);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild, place: false);

  @override
  double computeMinIntrinsicWidth(double height) =>
      _children.fold(0.0, (w, c) => math.max(w, c.getMinIntrinsicWidth(height)));

  @override
  double computeMaxIntrinsicWidth(double height) {
    final children = _children;
    return children.fold(0.0, (w, c) => w + c.getMaxIntrinsicWidth(height)) +
        _gaps(children.length);
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  double _intrinsicHeight(double width) {
    final children = _children;
    if (children.isEmpty) return 0;
    if (_fitsSideBySide(children, width)) {
      final share = width.isFinite ? (width - _gaps(children.length)) / children.length : width;
      return children.fold(0.0, (h, c) => math.max(h, c.getMaxIntrinsicHeight(share)));
    }
    return children.fold(0.0, (h, c) => h + c.getMaxIntrinsicHeight(width)) +
        _gaps(children.length);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
