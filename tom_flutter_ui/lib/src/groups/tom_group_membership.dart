/// Group membership that follows the element tree.
///
/// A widget is an immutable description, replaced by a new instance on every
/// rebuild of its parent and never told when it leaves the tree, so it cannot
/// own a registration: one made in its constructor counts each rebuilt
/// instance and every removed one until the garbage collector reaches it. The
/// element is the one object that knows what is mounted, so membership lives
/// there. [TomGroupMemberElement] joins the widget's group when the element
/// becomes active, moves the registration to the new widget on every update,
/// and leaves when the element is deactivated. A group's members are therefore
/// exactly the Tom widgets currently in the tree.
library;

import 'package:flutter/rendering.dart' show ParentData;
import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Keeps the element's widget registered with its [TomAuthorizable.tomGroup]
/// for exactly as long as the element is active.
///
/// Mixed into the element a Tom widget creates in `createElement`. The three
/// concrete elements below cover the widget kinds the package extends; a
/// custom Tom widget of another kind mixes this into its own element.
mixin TomGroupMemberElement on Element {
  /// The member to register for [widget], or `null` when it joins no group.
  ///
  /// Defaults to the widget itself when it is a [TomAuthorizable]. A widget
  /// that resolves through a group without being a member of it overrides
  /// this in its own element.
  @protected
  TomAuthorizable? groupMemberFor(Widget widget) => switch (widget) {
    final TomAuthorizable member => member,
    _ => null,
  };

  void _join(Widget widget) {
    final member = groupMemberFor(widget);
    member?.tomGroup?.register(member);
  }

  void _leave(Widget widget) {
    final member = groupMemberFor(widget);
    member?.tomGroup?.unregister(member);
  }

  /// Joins the group when the element is first mounted.
  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _join(widget);
  }

  /// Moves the registration from the replaced widget to the new one.
  @override
  void update(covariant Widget newWidget) {
    final previous = widget;
    super.update(newWidget);
    // The instance changed, and possibly its group: the registration follows
    // the widget now in the tree, never the one it replaced.
    _leave(previous);
    _join(widget);
  }

  /// Rejoins the group when the element is reinserted.
  @override
  void activate() {
    super.activate();
    _join(widget);
  }

  /// Leaves the group when the element leaves the tree.
  @override
  void deactivate() {
    _leave(widget);
    super.deactivate();
  }

  /// Leaves the group, if [deactivate] has not already.
  @override
  void unmount() {
    _leave(widget);
    super.unmount();
  }
}

/// The element of a stateless Tom widget: a [StatelessElement] that keeps its
/// widget's group membership — see [TomGroupMemberElement].
class TomStatelessGroupMemberElement extends StatelessElement
    with TomGroupMemberElement {
  /// Creates the element for [widget].
  TomStatelessGroupMemberElement(super.widget);
}

/// The element of a stateful Tom widget: a [StatefulElement] that keeps its
/// widget's group membership — see [TomGroupMemberElement].
class TomStatefulGroupMemberElement extends StatefulElement
    with TomGroupMemberElement {
  /// Creates the element for [widget].
  TomStatefulGroupMemberElement(super.widget);
}

/// The element of a parent-data Tom widget (`TomExpanded`, `TomFlexible`): a
/// [ParentDataElement] that keeps its widget's group membership — see
/// [TomGroupMemberElement].
class TomParentDataGroupMemberElement<T extends ParentData>
    extends ParentDataElement<T>
    with TomGroupMemberElement {
  /// Creates the element for [widget].
  TomParentDataGroupMemberElement(super.widget);
}
