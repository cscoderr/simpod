// ignore_for_file: must_be_immutable

import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide KeyEvent;
import 'package:flutter/services.dart';
import 'package:simpod_client/core/core.dart';
import 'package:simpod_core/simpod_core.dart'
    hide SimpodKeyEvent, SimpodKeyDownEvent;

class AXTreeNode extends Equatable {
  AXTreeNode({required this.axNode, AXTreeNode? parent}) : _parent = parent;

  final AXNode axNode;
  final AXTreeNode? _parent;
  AXTreeNode? get parent => _parent;

  bool isExpanded = true;
  bool isSelected = false;

  late final List<AXTreeNode> children = axNode.children
      .map((c) => AXTreeNode(axNode: c, parent: this))
      .toList();

  bool get hasChildren => children.isNotEmpty;
  bool get shouldShow => true;

  @override
  List<Object?> get props => [axNode];
}

class AXTreeRow {
  const AXTreeRow({
    required this.node,
    required this.index,
    required this.depth,
    required this.ticks,
    required this.lineToParent,
  });

  final AXTreeNode node;
  final int index;
  final int depth;

  final List<int> ticks;

  final bool lineToParent;
}

class AXTreeController extends ChangeNotifier {
  AXTreeController({required AXNode root}) {
    _root = _buildTree(root, parent: null);
    _rebuildRows();
  }

  late AXTreeNode _root;
  AXTreeNode get root => _root;

  AXTreeNode? _selection;
  AXTreeNode? get selection => _selection;

  List<AXTreeRow> _rows = [];
  List<AXTreeRow> get rows => _rows;

  final Map<AXTreeNode, int> _nodeToIndex = {};

  void replaceRoot(AXNode newRoot) {
    _selection = null;
    _root = _buildTree(newRoot, parent: null);
    _rebuildRows();
    notifyListeners();
  }

  void toggleExpand(AXTreeNode node) {
    node.isExpanded = !node.isExpanded;
    _rebuildRows();
    notifyListeners();
  }

  void selectNode(AXTreeNode? node) {
    if (node == _selection) return;
    _selection?.isSelected = false;
    _selection = node;
    _selection?.isSelected = true;
    notifyListeners();
  }

  void expandAll() {
    _setExpandedAll(_root, true);
    _rebuildRows();
    notifyListeners();
  }

  void collapseAll() {
    _setExpandedAll(_root, false);
    _rebuildRows();
    notifyListeners();
  }

  void navigateUp() => _navigate(-1);
  void navigateDown() => _navigate(1);

  void navigateLeft() {
    final sel = _selection;
    if (sel == null) {
      _navigate(-1);
      return;
    }
    if (sel.isExpanded && sel.hasChildren) {
      sel.isExpanded = false;
      _rebuildRows();
      notifyListeners();
    } else if (sel.parent != null) {
      selectNode(sel.parent);
    }
  }

  void navigateRight() {
    final sel = _selection;
    if (sel == null) {
      _navigate(1);
      return;
    }
    if (!sel.isExpanded && sel.hasChildren) {
      sel.isExpanded = true;
      _rebuildRows();
      notifyListeners();
    } else {
      _navigate(1);
    }
  }

  int rowIndexFor(AXTreeNode node) => _nodeToIndex[node] ?? -1;

  AXTreeNode _buildTree(AXNode ax, {required AXTreeNode? parent}) {
    final node = AXTreeNode(axNode: ax, parent: parent);
    // Children are lazily built inside AXTreeNode.children getter,
    // but we need to force them now so the tree is fully wired.
    for (final child in node.children) {
      // just accessing the getter is enough; children wire themselves
      final _ = child;
    }
    return node;
  }

  void _rebuildRows() {
    _rows = [];
    _nodeToIndex.clear();
    _buildRowsHelper(_root, depth: 0, ticks: []);
  }

  void _buildRowsHelper(
    AXTreeNode node, {
    required int depth,
    required List<int> ticks,
  }) {
    final idx = _rows.length;
    _rows.add(
      AXTreeRow(
        node: node,
        index: idx,
        depth: depth,
        ticks: List.unmodifiable(ticks),
        lineToParent: idx != 0 && node.parent != null,
      ),
    );
    _nodeToIndex[node] = idx;

    if (!node.isExpanded) return;

    final children = node.children;
    final childDepth = children.length > 1 ? depth + 1 : depth;

    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      final isLast = i == children.length - 1;
      final childTicks = [...ticks, if (!isLast && children.length > 1) depth];
      _buildRowsHelper(child, depth: childDepth, ticks: childTicks);
    }
  }

  void _setExpandedAll(AXTreeNode node, bool expanded) {
    node.isExpanded = expanded;
    for (final child in node.children) {
      _setExpandedAll(child, expanded);
    }
  }

  void _navigate(int delta) {
    if (_rows.isEmpty) return;
    final currentIdx = _selection == null ? -1 : rowIndexFor(_selection!);
    final nextIdx = (currentIdx + delta).clamp(0, _rows.length - 1);
    selectNode(_rows[nextIdx].node);
  }
}

class AXTreeWidget extends StatefulWidget {
  const AXTreeWidget({
    super.key,
    required this.root,
    this.onNodeSelected,
    this.onInitialize,
    this.showHidden = false,
  });

  final AXNode root;
  final void Function(AXNode node)? onNodeSelected;
  final void Function(AXNode node)? onInitialize;

  final bool showHidden;

  @override
  State<AXTreeWidget> createState() => _AXTreeWidgetState();
}

class _AXTreeWidgetState extends State<AXTreeWidget> {
  late AXTreeController _controller;
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  static const double _rowHeight = 28.0;
  static const double _indent = AppSpacing.lg;

  @override
  void initState() {
    super.initState();
    _controller = AXTreeController(root: widget.root);
    _controller.addListener(_onControllerChanged);
    widget.onInitialize?.call(widget.root);
  }

  @override
  void didUpdateWidget(AXTreeWidget old) {
    super.didUpdateWidget(old);
    if (old.root != widget.root) {
      _controller.replaceRoot(widget.root);
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        widget.onInitialize?.call(widget.root);
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
    _scrollToSelection();
  }

  void _scrollToSelection() {
    final sel = _controller.selection;
    if (sel == null) return;
    final idx = _controller.rowIndexFor(sel);
    if (idx < 0) return;
    final targetOffset = idx * _rowHeight;
    if (!_scrollController.hasClients) return;
    final viewportHeight = _scrollController.position.viewportDimension;
    final currentOffset = _scrollController.offset;
    if (targetOffset < currentOffset ||
        targetOffset + _rowHeight > currentOffset + viewportHeight) {
      _scrollController.animateTo(
        (targetOffset - viewportHeight / 2 + _rowHeight / 2).clamp(
          0,
          _scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _controller.rows.length,
        itemExtent: _rowHeight,
        itemBuilder: (context, index) {
          final row = _controller.rows[index];
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: _AXTreeRowWidget(
              key: ValueKey(row.node),
              row: row,
              rowHeight: _rowHeight,
              indent: _indent,
              controller: _controller,
              onTap: () {
                _focusNode.requestFocus();
                _controller.selectNode(row.node);
                widget.onNodeSelected?.call(row.node.axNode);
              },
              onToggle: () => _controller.toggleExpand(row.node),
            ),
          );
        },
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _controller.navigateUp();
      case LogicalKeyboardKey.arrowDown:
        _controller.navigateDown();
      case LogicalKeyboardKey.arrowLeft:
        _controller.navigateLeft();
      case LogicalKeyboardKey.arrowRight:
        _controller.navigateRight();
      default:
        break;
    }
  }
}

class _AXTreeRowWidget extends StatelessWidget {
  const _AXTreeRowWidget({
    super.key,
    required this.row,
    required this.rowHeight,
    required this.indent,
    required this.controller,
    required this.onTap,
    required this.onToggle,
  });

  final AXTreeRow row;
  final double rowHeight;
  final double indent;
  final AXTreeController controller;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = row.node.isSelected;
    final ax = row.node.axNode;
    final depth = row.depth;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.xs),
        ),
        child: Row(
          mainAxisAlignment: .center,
          children: [
            SizedBox(width: depth * indent),
            SizedBox(
              width: AppSpacing.xlg - AppSpacing.xs,
              child: row.node.hasChildren
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onToggle,
                      child: Icon(
                        row.node.isExpanded
                            ? CupertinoIcons.chevron_down
                            : CupertinoIcons.chevron_right,
                        size: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            Text(
              ax.shortRole,
              style: context.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                ax.displayName.isNotEmpty ? ax.displayName : ax.shortRole,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  color: ax.hidden
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                      : isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: .w500,
                  fontStyle: ax.hidden ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),

            if (!ax.enabled)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.sm - AppSpacing.xxs,
                ),
                child: Icon(
                  Icons.block,
                  size: 12,
                  color: theme.colorScheme.error.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
