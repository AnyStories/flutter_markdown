

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class MyMaterialTextSelectionControls extends MaterialTextSelectionControls {
  // Padding between the toolbar and the anchor.
  static const double _kToolbarContentDistanceBelow = 20.0;
  static const double _kToolbarContentDistance = 8.0;

  /// Builder for material-style copy/paste text selection toolbar.
  @override
  Widget buildToolbar(
      BuildContext context,
      Rect globalEditableRegion,
      double textLineHeight,
      Offset selectionMidpoint,
      List<TextSelectionPoint> endpoints,
      TextSelectionDelegate delegate,
      ClipboardStatusNotifier clipboardStatus,
      Offset? lastSecondaryTapDownPosition,
      ) {
    final TextSelectionPoint startTextSelectionPoint = endpoints[0];
    final TextSelectionPoint endTextSelectionPoint = endpoints.length > 1
        ? endpoints[1]
        : endpoints[0];
    final Offset anchorAbove = Offset(
        globalEditableRegion.left + selectionMidpoint.dx,
        globalEditableRegion.top + startTextSelectionPoint.point.dy - textLineHeight - _kToolbarContentDistance
    );
    final Offset anchorBelow = Offset(
      globalEditableRegion.left + selectionMidpoint.dx,
      globalEditableRegion.top + endTextSelectionPoint.point.dy + _kToolbarContentDistanceBelow,
    );

    return MyTextSelectionToolbar(
      anchorAbove: anchorAbove,
      anchorBelow: anchorBelow,
      clipboardStatus: clipboardStatus,
      handleCustomButton: () {
        delegate.textEditingValue = delegate.textEditingValue.copyWith(
          selection: TextSelection.collapsed(
            offset: delegate.textEditingValue.selection.baseOffset,
          ),
        );
        delegate.hideToolbar();
      },
    );
  }
}

class MyTextSelectionToolbar extends StatefulWidget {
  const MyTextSelectionToolbar({
    Key? key,
    required this.anchorAbove,
    required this.anchorBelow,
    this.clipboardStatus,
    this.handleCopy,
    this.handleCustomButton,
    this.handleCut,
    this.handlePaste,
    this.handleSelectAll,
  }) : super(key: key);

  final Offset anchorAbove;
  final Offset anchorBelow;
  final ClipboardStatusNotifier? clipboardStatus;
  final VoidCallback? handleCopy;
  final VoidCallback? handleCustomButton;
  final VoidCallback? handleCut;
  final VoidCallback? handlePaste;
  final VoidCallback? handleSelectAll;

  @override
  MyTextSelectionToolbarState createState() => MyTextSelectionToolbarState();
}

class MyTextSelectionToolbarState extends State<MyTextSelectionToolbar> {
  void _onChangedClipboardStatus() {
    setState(() {
      // Inform the widget that the value of clipboardStatus has changed.
    });
  }

  @override
  void initState() {
    super.initState();
    widget.clipboardStatus?.addListener(_onChangedClipboardStatus);
    widget.clipboardStatus?.update();
  }

  @override
  void didUpdateWidget(MyTextSelectionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clipboardStatus != oldWidget.clipboardStatus) {
      widget.clipboardStatus?.addListener(_onChangedClipboardStatus);
      oldWidget.clipboardStatus?.removeListener(_onChangedClipboardStatus);
    }
    widget.clipboardStatus?.update();
  }

  @override
  void dispose() {
    super.dispose();
    if (!(widget.clipboardStatus?.disposed??false)) {
      widget.clipboardStatus?.removeListener(_onChangedClipboardStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);

    final List<_TextSelectionToolbarItemData> itemDatas = <_TextSelectionToolbarItemData>[
      if (widget.handleCut != null)
        _TextSelectionToolbarItemData(
          label: localizations.cutButtonLabel,
          onPressed: widget.handleCut,
        ),
      if (widget.handleCopy != null)
        _TextSelectionToolbarItemData(
          label: localizations.copyButtonLabel,
          onPressed: widget.handleCopy,
        ),
      if (widget.handlePaste != null
          && widget.clipboardStatus?.value == ClipboardStatus.pasteable)
        _TextSelectionToolbarItemData(
          label: localizations.pasteButtonLabel,
          onPressed: widget.handlePaste,
        ),
      if (widget.handleSelectAll != null)
        _TextSelectionToolbarItemData(
          label: localizations.selectAllButtonLabel,
          onPressed: widget.handleSelectAll,
        ),
      _TextSelectionToolbarItemData(
        onPressed: widget.handleCustomButton,
        label: '写想法',
      ),
    ];

    int childIndex = 0;
    return TextSelectionToolbar(
      anchorAbove: widget.anchorAbove,
      anchorBelow: widget.anchorBelow,
      toolbarBuilder: (BuildContext context, Widget child) {
        return Container(
          color: Colors.pink,
          child: child,
        );
      },
      children: itemDatas.map((_TextSelectionToolbarItemData itemData) {
        return TextSelectionToolbarTextButton(
          padding: TextSelectionToolbarTextButton.getPadding(childIndex++, itemDatas.length),
          onPressed: itemData.onPressed,
          child: Text(itemData.label),
        );
      }).toList(),
    );
  }
}

class _TextSelectionToolbarItemData {
  const _TextSelectionToolbarItemData({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;
}