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
  Key? alignLeftToKey;
  Key? alignRightToKey;
  double alignmentGap = 0;
  Key? componentKey;

  _ComponentData({required this.child, this.flags = 0, this.gapBefore = 0});

  AclComponent toComponent() {
    return AclComponent(
      child: child,
      flags: flags,
      gapBefore: gapBefore,
      preferredSize: preferredSize,
      minimumSize: minimumSize,
      maximumSize: maximumSize,
      referenceKey: referenceKey,
      alignLeftToKey: alignLeftToKey,
      alignRightToKey: alignRightToKey,
      alignmentGap: alignmentGap,
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

  AclBuilder() {
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

  AclBuilder setComp(Key referenceKey, int otherAttr) {
    if (_currentComponent != null) {
      _currentComponent!.referenceKey = referenceKey;
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

  AclBuilder setKey(Key key) {
    if (_currentComponent != null) {
      _currentComponent!.componentKey = key;
    }
    return this;
  }

  AclBuilder sameSizeAs(Key referenceKey) =>
      setComp(referenceKey, AclFlags.otherDim);

  AclBuilder sameWidthAs(Key referenceKey) =>
      setComp(referenceKey, AclFlags.otherDimX);

  AclBuilder sameHeightAs(Key referenceKey) =>
      setComp(referenceKey, AclFlags.otherDimY);

  AclBuilder alignLeftToComp(Key referenceKey, {double gap = 0}) {
    if (_currentComponent != null) {
      _currentComponent!.alignLeftToKey = referenceKey;
      _currentComponent!.alignRightToKey = null;
      _currentComponent!.alignmentGap = gap;
    }
    return this;
  }

  AclBuilder alignRightToComp(Key referenceKey, {double gap = 0}) {
    if (_currentComponent != null) {
      _currentComponent!.alignRightToKey = referenceKey;
      _currentComponent!.alignLeftToKey = null;
      _currentComponent!.alignmentGap = gap;
    }
    return this;
  }

  AclBuilder append(Widget child, {double dist = 0}) {
    _currentComponent = _ComponentData(
      child: child,
      flags: _defaultFlags,
      gapBefore: dist,
    );
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

  Acl build() {
    return Acl(
      rows: _rows.map((row) => row.toRow()).toList(),
      borderStyle: _borderStyle,
      focusedBorderStyle: _focusedBorderStyle,
      padding: _padding,
      backgroundColor: _backgroundColor,
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

class AclGroupBuilder {
  String? _title;
  Widget? _child;
  AclBorderStyle _borderStyle = const AclBorderStyle(
    lineKind: AclBorderLineKind.doubleLine,
    with3dEffect: true,
  );
  AclBorderStyle? _focusedBorderStyle;
  EdgeInsetsGeometry _padding = const EdgeInsets.all(8);
  Color? _backgroundColor;
  TextStyle? _titleStyle;
  AclGroupTitlePosition _titlePosition = AclGroupTitlePosition.topLeft;

  AclGroupBuilder title(String title) {
    _title = title;
    return this;
  }

  AclGroupBuilder child(Widget child) {
    _child = child;
    return this;
  }

  AclGroupBuilder borderStyle(AclBorderStyle style) {
    _borderStyle = style;
    return this;
  }

  AclGroupBuilder focusedBorderStyle(AclBorderStyle style) {
    _focusedBorderStyle = style;
    return this;
  }

  AclGroupBuilder padding(EdgeInsetsGeometry padding) {
    _padding = padding;
    return this;
  }

  AclGroupBuilder backgroundColor(Color color) {
    _backgroundColor = color;
    return this;
  }

  AclGroupBuilder titleStyle(TextStyle style) {
    _titleStyle = style;
    return this;
  }

  AclGroupBuilder titlePosition(AclGroupTitlePosition position) {
    _titlePosition = position;
    return this;
  }

  AclGroup buildWithContainer(void Function(AclBuilder) builder) {
    final b = AclBuilder();
    builder(b);
    return AclGroup(
      title: _title,
      borderStyle: _borderStyle,
      focusedBorderStyle: _focusedBorderStyle,
      padding: _padding,
      backgroundColor: _backgroundColor,
      titleStyle: _titleStyle,
      titlePosition: _titlePosition,
      child: b.build(),
    );
  }

  AclGroup build() {
    return AclGroup(
      title: _title,
      borderStyle: _borderStyle,
      focusedBorderStyle: _focusedBorderStyle,
      padding: _padding,
      backgroundColor: _backgroundColor,
      titleStyle: _titleStyle,
      titlePosition: _titlePosition,
      child: _child ?? const SizedBox.shrink(),
    );
  }
}
