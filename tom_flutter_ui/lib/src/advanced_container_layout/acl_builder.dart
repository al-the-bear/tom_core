import 'package:flutter/material.dart';

import 'acl_container.dart';
import 'acl_flags.dart';
import 'row_alignment.dart';

class _ComponentData {
  Widget child;
  int flags;
  double gapBefore;
  Size? preferredSize;
  Size? minimumSize;
  Size? maximumSize;
  Key? referenceKey;
  Key? alignXToKey;
  AclAxisPointX? alignXFrom;
  AclAxisPointX? alignXTo;
  double alignXGap = 0;
  Key? alignYToKey;
  AclAxisPointY? alignYFrom;
  AclAxisPointY? alignYTo;
  double alignYGap = 0;
  AclRowCrossAlignment rowCrossAlignment = AclRowCrossAlignment.center;
  Key? componentKey;

  _ComponentData({
    required this.child,
    this.flags = 0,
    this.gapBefore = 0,
    this.componentKey,
  });

  AclComponent toComponent() {
    return AclComponent(
      child: child,
      flags: flags,
      gapBefore: gapBefore,
      preferredSize: preferredSize,
      minimumSize: minimumSize,
      maximumSize: maximumSize,
      referenceKey: referenceKey,
      alignXToKey: alignXToKey,
      alignXFrom: alignXFrom,
      alignXTo: alignXTo,
      alignXGap: alignXGap,
      alignYToKey: alignYToKey,
      alignYFrom: alignYFrom,
      alignYTo: alignYTo,
      alignYGap: alignYGap,
      rowCrossAlignment: rowCrossAlignment,
      componentKey: componentKey,
    );
  }
}

class _RowData {
  List<_ComponentData> components = [];
  RowAlignment alignment = RowAlignment.left;
  double gapBefore = 0;

  AclRow toRow() {
    return AclRow(
      components: components
          .map((component) => component.toComponent())
          .toList(),
      alignment: alignment,
      gapBefore: gapBefore,
    );
  }
}

class AclBuilder {
  final List<_RowData> _rows = [];
  _RowData _currentRow = _RowData();
  _ComponentData? _currentComponent;

  int _defaultFlags = 0;
  AclBorderStyle _borderStyle = const AclBorderStyle.none();
  AclBorderStyle? _focusedBorderStyle;
  EdgeInsetsGeometry _padding = EdgeInsets.zero;
  Color? _backgroundColor;
  String? _title;
  TextStyle? _titleStyle;
  AclTitlePosition _titlePosition;
  final Map<Object, Key> _referenceKeyByObject = Map<Object, Key>.identity();

  AclBuilder({
    String? title,
    AclBorderStyle borderStyle = const AclBorderStyle.none(),
    AclBorderStyle? focusedBorderStyle,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    Color? backgroundColor,
    TextStyle? titleStyle,
    AclTitlePosition titlePosition = AclTitlePosition.topLeft,
  }) : _title = title,
       _borderStyle = borderStyle,
       _focusedBorderStyle = focusedBorderStyle,
       _padding = padding,
       _backgroundColor = backgroundColor,
       _titleStyle = titleStyle,
       _titlePosition = titlePosition {
    _rows.add(_currentRow);
  }

  AclBuilder setDefaultFlags(int flags) {
    _defaultFlags = flags;
    return this;
  }

  int get defaultFlags => _defaultFlags;

  AclBuilder setAttr(int attr) {
    if (_currentComponent != null) {
      _currentComponent!.flags |= attr;
    }
    return this;
  }

  AclBuilder clearAttr(int newAttr) {
    if (_currentComponent != null) {
      _currentComponent!.flags &= ~newAttr;
    }
    return this;
  }

  AclBuilder setComp(Object reference, int otherAttr) {
    if (_currentComponent != null) {
      _currentComponent!.referenceKey = _resolveReferenceKey(reference);
      _currentComponent!.flags |= (otherAttr & AclFlags.otherDim);
    }
    return this;
  }

  AclBuilder setPSize(double width, double height) {
    if (_currentComponent != null) {
      _currentComponent!.preferredSize = Size(width, height);
    }
    return this;
  }

  AclBuilder setWidthInChars(
    int chars, {
    double charWidth = 8,
    double height = 40,
  }) {
    if (_currentComponent == null) {
      return this;
    }

    final width = (chars * charWidth).clamp(0, double.infinity).toDouble();
    final currentHeight = _currentComponent!.preferredSize?.height ?? height;
    _currentComponent!.preferredSize = Size(width, currentHeight);
    return this;
  }

  AclBuilder setMSize(double width, double height) {
    if (_currentComponent != null) {
      _currentComponent!.minimumSize = Size(width, height);
    }
    return this;
  }

  AclBuilder setXSize(double width, double height) {
    if (_currentComponent != null) {
      _currentComponent!.maximumSize = Size(width, height);
    }
    return this;
  }

  AclBuilder sameWidthAs(Object reference) =>
      setComp(reference, AclFlags.otherDimX);

  AclBuilder sameHeightAs(Object reference) =>
      setComp(reference, AclFlags.otherDimY);

  AclBuilder alignTopInRow() {
    if (_currentComponent != null) {
      _currentComponent!.rowCrossAlignment = AclRowCrossAlignment.top;
    }
    return this;
  }

  AclBuilder alignCenterInRow() {
    if (_currentComponent != null) {
      _currentComponent!.rowCrossAlignment = AclRowCrossAlignment.center;
    }
    return this;
  }

  AclBuilder alignBottomInRow() {
    if (_currentComponent != null) {
      _currentComponent!.rowCrossAlignment = AclRowCrossAlignment.bottom;
    }
    return this;
  }

  AclBuilder alignLeftToLeft(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.left,
        referencePoint: AclAxisPointX.left,
        gap: gap,
      );

  AclBuilder alignLeftToCenter(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.left,
        referencePoint: AclAxisPointX.center,
        gap: gap,
      );

  AclBuilder alignLeftToRight(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.left,
        referencePoint: AclAxisPointX.right,
        gap: gap,
      );

  AclBuilder alignCenterToLeft(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.center,
        referencePoint: AclAxisPointX.left,
        gap: gap,
      );

  AclBuilder alignCenterToCenter(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.center,
        referencePoint: AclAxisPointX.center,
        gap: gap,
      );

  AclBuilder alignCenterToRight(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.center,
        referencePoint: AclAxisPointX.right,
        gap: gap,
      );

  AclBuilder alignRightToLeft(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.right,
        referencePoint: AclAxisPointX.left,
        gap: gap,
      );

  AclBuilder alignRightToCenter(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.right,
        referencePoint: AclAxisPointX.center,
        gap: gap,
      );

  AclBuilder alignRightToRight(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.right,
        referencePoint: AclAxisPointX.right,
        gap: gap,
      );

  AclBuilder alignTopToTop(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.top,
        referencePoint: AclAxisPointY.top,
        gap: gap,
      );

  AclBuilder alignTopToCenter(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.top,
        referencePoint: AclAxisPointY.center,
        gap: gap,
      );

  AclBuilder alignTopToBottom(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.top,
        referencePoint: AclAxisPointY.bottom,
        gap: gap,
      );

  AclBuilder alignCenterToTop(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.center,
        referencePoint: AclAxisPointY.top,
        gap: gap,
      );

  AclBuilder alignCenterToCenterY(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.center,
        referencePoint: AclAxisPointY.center,
        gap: gap,
      );

  AclBuilder alignCenterToBottom(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.center,
        referencePoint: AclAxisPointY.bottom,
        gap: gap,
      );

  AclBuilder alignBottomToTop(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.bottom,
        referencePoint: AclAxisPointY.top,
        gap: gap,
      );

  AclBuilder alignBottomToCenter(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.bottom,
        referencePoint: AclAxisPointY.center,
        gap: gap,
      );

  AclBuilder alignBottomToBottom(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.bottom,
        referencePoint: AclAxisPointY.bottom,
        gap: gap,
      );

  AclBuilder _setHorizontalAlignment({
    required Object reference,
    required AclAxisPointX selfPoint,
    required AclAxisPointX referencePoint,
    required double gap,
  }) {
    if (_currentComponent != null) {
      _currentComponent!.alignXToKey = _resolveReferenceKey(reference);
      _currentComponent!.alignXFrom = selfPoint;
      _currentComponent!.alignXTo = referencePoint;
      _currentComponent!.alignXGap = gap;
    }
    return this;
  }

  AclBuilder _setVerticalAlignment({
    required Object reference,
    required AclAxisPointY selfPoint,
    required AclAxisPointY referencePoint,
    required double gap,
  }) {
    if (_currentComponent != null) {
      _currentComponent!.alignYToKey = _resolveReferenceKey(reference);
      _currentComponent!.alignYFrom = selfPoint;
      _currentComponent!.alignYTo = referencePoint;
      _currentComponent!.alignYGap = gap;
    }
    return this;
  }

  Key _resolveReferenceKey(Object reference) {
    if (reference is Key) {
      return reference;
    }
    return _referenceKeyByObject.putIfAbsent(
      reference,
      () => GlobalKey(debugLabel: 'acl-ref-${_referenceKeyByObject.length}'),
    );
  }

  AclBuilder append(Widget child, {double dist = 0}) {
    final componentKey = _resolveReferenceKey(child);
    _currentComponent = _ComponentData(
      child: child,
      flags: _defaultFlags,
      gapBefore: dist,
      componentKey: componentKey,
    );
    _referenceKeyByObject[child] = componentKey;
    _currentRow.components.add(_currentComponent!);
    return this;
  }

  AclBuilder newRow({double dist = 0}) {
    _currentRow = _RowData()..gapBefore = dist;
    _rows.add(_currentRow);
    _currentComponent = null;
    return this;
  }

  AclBuilder setRowAlignment(RowAlignment align) {
    _currentRow.alignment = align;
    return this;
  }

  AclBuilder setBorderStyle(AclBorderStyle style) {
    _borderStyle = style;
    return this;
  }

  AclBuilder setBorderInsets(EdgeInsetsGeometry insets) {
    _borderStyle = _borderStyle.copyWith(borderInsets: insets);
    return this;
  }

  AclBuilder setFocusedBorderStyle(AclBorderStyle style) {
    _focusedBorderStyle = style;
    return this;
  }

  AclBuilder setPadding(EdgeInsetsGeometry padding) {
    _padding = padding;
    return this;
  }

  AclBuilder setBackgroundColor(Color color) {
    _backgroundColor = color;
    return this;
  }

  AclBuilder setTitle(String? title) {
    _title = title;
    return this;
  }

  AclBuilder setTitleStyle(TextStyle style) {
    _titleStyle = style;
    return this;
  }

  AclBuilder setTitlePosition(AclTitlePosition position) {
    _titlePosition = position;
    return this;
  }

  Acl build() {
    return Acl(
      rows: _rows.map((row) => row.toRow()).toList(),
      borderStyle: _borderStyle,
      focusedBorderStyle: _focusedBorderStyle,
      padding: _padding,
      backgroundColor: _backgroundColor,
      title: _title,
      titleStyle: _titleStyle,
      titlePosition: _titlePosition,
    );
  }
}

extension AclBuilderExtensions on AclBuilder {
  AclBuilder expandX() => setAttr(AclFlags.expandX);
  AclBuilder expandY() => setAttr(AclFlags.expandY);
  AclBuilder expand() => setAttr(AclFlags.expand);

  AclBuilder alignLeft() => setRowAlignment(RowAlignment.left);
  AclBuilder alignCenter() => setRowAlignment(RowAlignment.center);
  AclBuilder alignRight() => setRowAlignment(RowAlignment.right);
}

// ignore: non_constant_identifier_names
Widget AclBuild(void Function(AclBuilder) builder) {
  final b = AclBuilder();
  builder(b);
  return b.build();
}

class AclRowDef {
  final List<Widget> children;
  final RowAlignment alignment;
  final double gapBefore;
  final List<int>? childFlags;
  final double childSpacing;

  const AclRowDef({
    required this.children,
    this.alignment = RowAlignment.left,
    this.gapBefore = 0,
    this.childFlags,
    this.childSpacing = 0,
  });
}

// ignore: non_constant_identifier_names
Acl AclColumn(List<AclRowDef> rowDefs) {
  final builder = AclBuilder();

  for (int i = 0; i < rowDefs.length; i++) {
    final rowDef = rowDefs[i];

    if (i > 0) {
      builder.newRow(dist: rowDef.gapBefore);
    } else if (rowDef.gapBefore > 0) {
      builder.newRow(dist: rowDef.gapBefore);
    }

    builder.setRowAlignment(rowDef.alignment);

    for (int j = 0; j < rowDef.children.length; j++) {
      final dist = j > 0 ? rowDef.childSpacing : 0.0;
      builder.append(rowDef.children[j], dist: dist);

      if (rowDef.childFlags != null && j < rowDef.childFlags!.length) {
        builder.setAttr(rowDef.childFlags![j]);
      }
    }
  }

  return builder.build();
}
