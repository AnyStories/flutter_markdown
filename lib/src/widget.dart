// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:meta/meta.dart';

import '_functions_io.dart' if (dart.library.html) '_functions_web.dart';
import 'builder.dart';
import 'custom_pop_up_menu.dart';
import 'style_sheet.dart';

/// Signature for callbacks used by [MarkdownWidget] when the user taps a link.
/// The callback will return the link text, destination, and title from the
/// Markdown link tag in the document.
///
/// Used by [MarkdownWidget.onTapLink].
typedef void MarkdownTapLinkCallback(String text, String? href, String title);

// long press
typedef void MarkdownLongPressCallback(String text);

/// Signature for custom image widget.
///
/// Used by [MarkdownWidget.imageBuilder]
typedef Widget MarkdownImageBuilder(Uri uri, String? title, String? alt);

/// Signature for custom checkbox widget.
///
/// Used by [MarkdownWidget.checkboxBuilder]
typedef Widget MarkdownCheckboxBuilder(bool value);

/// Signature for custom bullet widget.
///
/// Used by [MarkdownWidget.bulletBuilder]
typedef Widget MarkdownBulletBuilder(int index, BulletStyle style);

/// Enumeration sent to the user when calling [MarkdownBulletBuilder]
///
/// Use this to differentiate the bullet styling when building your own.
///

typedef ParagraphPressEditCallBack = Function(String md5, String content);

typedef Widget CommentBubbleBuilder(String paragraphId);

typedef LongPressCallBack = Function(String paragraphId);

enum BulletStyle {
  orderedList,
  unorderedList,
}

/// Creates a format [TextSpan] given a string.
///
/// Used by [MarkdownWidget] to highlight the contents of `pre` elements.
abstract class SyntaxHighlighter {
  // ignore: one_member_abstracts
  /// Returns the formatted [TextSpan] for the given string.
  TextSpan format(String source);
}

abstract class MarkdownElementBuilder {
  /// Called when an Element has been reached, before its children have been
  /// visited.
  void visitElementBefore(md.Element element) {}

  /// Called when a text node has been reached.
  ///
  /// If [MarkdownWidget.styleSheet] has a style of this tag, will passing
  /// to [preferredStyle].
  ///
  /// If you needn't build a widget, return null.
  Widget? visitText(md.Text text, TextStyle? preferredStyle) => null;

  /// Called when an Element has been reached, after its children have been
  /// visited.
  ///
  /// If [MarkdownWidget.styleSheet] has a style of this tag, will passing
  /// to [preferredStyle].
  ///
  /// If you needn't build a widget, return null.
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) =>
      null;
}

/// Enum to specify which theme being used when creating [MarkdownStyleSheet]
///
/// [material] - create MarkdownStyleSheet based on MaterialTheme
/// [cupertino] - create MarkdownStyleSheet based on CupertinoTheme
/// [platform] - create MarkdownStyleSheet based on the Platform where the
/// is running on. Material on Android and Cupertino on iOS
enum MarkdownStyleSheetBaseTheme { material, cupertino, platform }

/// Enumeration of alignment strategies for the cross axis of list items.
enum MarkdownListItemCrossAxisAlignment {
  /// Uses [CrossAxisAlignment.baseline] for the row the bullet and the list
  /// item are placed in.
  ///
  /// This alignment will ensure that the bullet always lines up with
  /// the list text on the baseline.
  ///
  /// However, note that this alignment does not support intrinsic height
  /// measurements because [RenderFlex] does not support it for
  /// [CrossAxisAlignment.baseline].
  /// See https://github.com/flutter/flutter_markdown/issues/311 for cases,
  /// where this might be a problem for you.
  ///
  /// See also:
  /// * [start], which allows for intrinsic height measurements.
  baseline,

  /// Uses [CrossAxisAlignment.start] for the row the bullet and the list item
  /// are placed in.
  ///
  /// This alignment will ensure that intrinsic height measurements work.
  ///
  /// However, note that this alignment might not line up the bullet with the
  /// list text in the way you would expect in certain scenarios.
  /// See https://github.com/flutter/flutter_markdown/issues/169 for example
  /// cases that do not produce expected results.
  ///
  /// See also:
  /// * [baseline], which will position the bullet and list item on the
  ///   baseline.
  start,
}

/// A base class for widgets that parse and display Markdown.
///
/// Supports all standard Markdown from the original
/// [Markdown specification](https://github.github.com/gfm/).
///
/// See also:
///
///  * [Markdown], which is a scrolling container of Markdown.
///  * [MarkdownBody], which is a non-scrolling container of Markdown.
///  * <https://github.github.com/gfm/>
abstract class MarkdownWidget extends StatefulWidget {
  /// Creates a widget that parses and displays Markdown.
  ///
  /// The [data] argument must not be null.
  const MarkdownWidget(
      {Key? key,
      this.data,
      this.nodes,
      this.selectable = false,
      this.styleSheet,
      this.styleSheetTheme = MarkdownStyleSheetBaseTheme.material,
      this.syntaxHighlighter,
      this.onTapLink,
      this.longPressCallback,
      this.onTapText,
      this.imageDirectory,
      this.blockSyntaxes,
      this.inlineSyntaxes,
      this.extensionSet,
      this.imageBuilder,
      this.checkboxBuilder,
      this.bulletBuilder,
      this.builders = const {},
      this.fitContent = false,
      this.bottomView,
      this.selectedBackgroundColor = Colors.transparent,
      this.listItemCrossAxisAlignment =
          MarkdownListItemCrossAxisAlignment.baseline,
      this.highLightStyle,
      this.paragraphPressEditCallBack,
      this.commentBubbleBuilder,
      this.contentTapCallBack,
      this.longPressCallBack})
      : assert(data != null || nodes != null),
        assert(selectable != null),
        super(key: key);

  /// The Markdown to display.
  final String? data;

  final List<md.Node>? nodes;

  //段落选中的颜色
  final Color selectedBackgroundColor;

  final ContentTapCallBack? contentTapCallBack;

  final LongPressCallBack? longPressCallBack;

  //底部点赞和分享的视图
  final Widget? bottomView;

  final ParagraphPressEditCallBack? paragraphPressEditCallBack;

  /// If true, the text is selectable.
  ///
  /// Defaults to false.
  final bool selectable;

  /// The styles to use when displaying the Markdown.
  ///
  /// If null, the styles are inferred from the current [Theme].
  final MarkdownStyleSheet? styleSheet;

  /// Setting to specify base theme for MarkdownStyleSheet
  ///
  /// Default to [MarkdownStyleSheetBaseTheme.material]
  final MarkdownStyleSheetBaseTheme? styleSheetTheme;

  /// The syntax highlighter used to color text in `pre` elements.
  ///
  /// If null, the [MarkdownStyleSheet.code] style is used for `pre` elements.
  final SyntaxHighlighter? syntaxHighlighter;

  final TextStyle? highLightStyle;

  /// Called when the user taps a link.
  final MarkdownTapLinkCallback? onTapLink;

  final MarkdownLongPressCallback? longPressCallback;

  /// Default tap handler used when [selectable] is set to true
  final VoidCallback? onTapText;

  /// The base directory holding images referenced by Img tags with local or network file paths.
  final String? imageDirectory;

  /// Collection of custom block syntax types to be used parsing the Markdown data.
  final List<md.BlockSyntax>? blockSyntaxes;

  /// Collection of custom inline syntax types to be used parsing the Markdown data.
  final List<md.InlineSyntax>? inlineSyntaxes;

  /// Markdown syntax extension set
  ///
  /// Defaults to [md.ExtensionSet.gitHubFlavored]
  final md.ExtensionSet? extensionSet;

  /// Call when build an image widget.
  final MarkdownImageBuilder? imageBuilder;

  /// Call when build a checkbox widget.
  final MarkdownCheckboxBuilder? checkboxBuilder;

  /// Called when building a bullet
  final MarkdownBulletBuilder? bulletBuilder;

  final CommentBubbleBuilder? commentBubbleBuilder;

  /// Render certain tags, usually used with [extensionSet]
  ///
  /// For example, we will add support for `sub` tag:
  ///
  /// ```dart
  /// builders: {
  ///   'sub': SubscriptBuilder(),
  /// }
  /// ```
  ///
  /// The `SubscriptBuilder` is a subclass of [MarkdownElementBuilder].
  final Map<String, MarkdownElementBuilder> builders;

  /// Whether to allow the widget to fit the child content.
  final bool fitContent;

  /// Controls the cross axis alignment for the bullet and list item content
  /// in lists.
  ///
  /// Defaults to [MarkdownListItemCrossAxisAlignment.baseline], which
  /// does not allow for intrinsic height measurements.
  final MarkdownListItemCrossAxisAlignment listItemCrossAxisAlignment;

  /// Subclasses should override this function to display the given children,
  /// which are the parsed representation of [data].
  @protected
  Widget build(BuildContext context, List<Widget>? children);

  @override
  _MarkdownWidgetState createState() => _MarkdownWidgetState();
}

class _MarkdownWidgetState extends State<MarkdownWidget>
    implements MarkdownBuilderDelegate {
  List<Widget>? _children;
  final List<GestureRecognizer> _recognizers = <GestureRecognizer>[];
  Timer? _timer;
  String? selectedMd5;

  @override
  void didChangeDependencies() {
    _parseMarkdown();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(MarkdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data ||
        widget.styleSheet != oldWidget.styleSheet) {
      _parseMarkdown();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _parseMarkdown() {
    final MarkdownStyleSheet fallbackStyleSheet =
        kFallbackStyle(context, widget.styleSheetTheme);
    final MarkdownStyleSheet styleSheet =
        fallbackStyleSheet.merge(widget.styleSheet);

    _disposeRecognizers();

    final List<md.Node>? nodes =
        widget.data != null ? _getMarkdownNodes(widget.data!) : widget.nodes;

    // Configure a Markdown widget builder to traverse the AST nodes and
    // create a widget tree based on the elements.
    final MarkdownBuilder builder = MarkdownBuilder(
        delegate: this,
        selectable: widget.selectable,
        styleSheet: styleSheet,
        imageDirectory: widget.imageDirectory,
        imageBuilder: widget.imageBuilder,
        checkboxBuilder: widget.checkboxBuilder,
        bulletBuilder: widget.bulletBuilder,
        builders: widget.builders,
        fitContent: widget.fitContent,
        listItemCrossAxisAlignment: widget.listItemCrossAxisAlignment,
        onTapText: widget.onTapText,
        selectedBackgroundColor: widget.selectedBackgroundColor,
        selectTextMd5: selectedMd5);

    _children = builder.build(nodes!);
    if (_children != null && widget.bottomView != null) {
      _children!.add(widget.bottomView!);
    }
  }

  List<md.Node>? _getMarkdownNodes(String data) {
    final List<String> lines = data.split(RegExp(r'\r?\n'));
    final md.Document document = md.Document(
      extensionSet: widget.extensionSet ?? md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [TaskListSyntax()],
      encodeHtml: false,
    );
    return document.parseLines(lines);
  }

  void _disposeRecognizers() {
    if (_recognizers.isEmpty) return;
    _timer?.cancel();
    final List<GestureRecognizer> localRecognizers =
        List<GestureRecognizer>.from(_recognizers);
    _recognizers.clear();
    for (GestureRecognizer recognizer in localRecognizers) recognizer.dispose();
  }

  @override
  GestureRecognizer createLink(String text, String? href, String title) {
    final TapGestureRecognizer recognizer = TapGestureRecognizer()
      ..onTap = () {
        if (widget.onTapLink != null) {
          widget.onTapLink!(text, href, title);
        }
      };
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code) {
    code = code.replaceAll(RegExp(r'\n$'), '');
    if (widget.syntaxHighlighter != null) {
      return widget.syntaxHighlighter!.format(code);
    }
    return TextSpan(style: styleSheet.code, text: code);
  }

  @override
  Widget build(BuildContext context) => widget.build(context, _children);

  final contentColor = Color(0xff333740).withOpacity(0.95);
  List<ItemModel> menuItems = [
    ItemModel('comment', Icons.edit),
  ];

  Widget _buildLongPressMenu({required Function onEditTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: GestureDetector(
        onTap: () {
          onEditTap();
        },
        child: Container(
            color: contentColor,
            width: 80,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: 4,
                ),
                Icon(
                  menuItems[0].icon,
                  size: 20,
                  color: Colors.white,
                ),
                Container(
                  margin: EdgeInsets.only(top: 2),
                  child: Text(
                    menuItems[0].title,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                SizedBox(
                  height: 4,
                ),
              ],
            )),
      ),
    );
  }

  final controlMap = Map<String, CustomPopupMenuController>();

  @override
  Widget formatParagraphText(
      String paragraphId,
      InlineSpan inlineSpan,
      MarkdownStyleSheet styleSheet,
      TextStyle? textStyle,
      TextAlign textAlign) {
    if (controlMap[paragraphId] == null) {
      controlMap[paragraphId] = CustomPopupMenuController();
    }

    return CustomPopupMenu(
      child: GestureDetector(
        child: Container(
            child: Text.rich(
          TextSpan(children: [
            inlineSpan,
            WidgetSpan(
                child: widget.commentBubbleBuilder != null
                    ? widget.commentBubbleBuilder!(paragraphId)
                    : Container())
          ]),
          textScaleFactor: styleSheet.textScaleFactor!,
          textAlign: textAlign,
          overflow: TextOverflow.visible,
        )),
      ),
      menuBuilder: () {
        return _buildLongPressMenu(onEditTap: () {
          controlMap[paragraphId]?.hideMenu();
          if (widget.paragraphPressEditCallBack != null) {
            widget.paragraphPressEditCallBack!(
                paragraphId, inlineSpan.toPlainText());
          }
        });
      },
      barrierColor: Colors.transparent,
      pressType: PressType.longPress,
      arrowColor: contentColor,
      verticalMargin: 0,
      menuVisibleChange: (visible) {
        debugPrint("menuVisibleChange--$visible");

        if (visible == true) {
          selectedMd5 = paragraphId;
          if (widget.longPressCallBack != null) {
            widget.longPressCallBack!(paragraphId);
          }
        } else {
          selectedMd5 = "";
        }
        _parseMarkdown();
      },
      controller: controlMap[paragraphId],
      contentTapCallBack: widget.contentTapCallBack,
    );
  }
}

/// A non-scrolling widget that parses and displays Markdown.
///
/// Supports all GitHub Flavored Markdown from the
/// [specification](https://github.github.com/gfm/).
///
/// See also:
///
///  * [Markdown], which is a scrolling container of Markdown.
///  * <https://github.github.com/gfm/>
class MarkdownBody extends MarkdownWidget {
  /// Creates a non-scrolling widget that parses and displays Markdown.
  const MarkdownBody({
    Key? key,
    String? data,
    List<md.Node>? nodes,
    bool selectable = false,
    MarkdownStyleSheet? styleSheet,
    MarkdownStyleSheetBaseTheme? styleSheetTheme,
    SyntaxHighlighter? syntaxHighlighter,
    MarkdownTapLinkCallback? onTapLink,
    VoidCallback? onTapText,
    String? imageDirectory,
    List<md.BlockSyntax>? blockSyntaxes,
    List<md.InlineSyntax>? inlineSyntaxes,
    md.ExtensionSet? extensionSet,
    MarkdownImageBuilder? imageBuilder,
    MarkdownCheckboxBuilder? checkboxBuilder,
    MarkdownBulletBuilder? bulletBuilder,
    CommentBubbleBuilder? commentBubbleBuilder,
    Map<String, MarkdownElementBuilder> builders = const {},
    MarkdownListItemCrossAxisAlignment listItemCrossAxisAlignment =
        MarkdownListItemCrossAxisAlignment.baseline,
    this.shrinkWrap = true,
    this.fitContent = true,
    this.selectedBackgroundColor = Colors.transparent,
  }) : super(
            key: key,
            data: data,
            nodes: nodes,
            selectable: selectable,
            styleSheet: styleSheet,
            styleSheetTheme: styleSheetTheme,
            syntaxHighlighter: syntaxHighlighter,
            onTapLink: onTapLink,
            onTapText: onTapText,
            imageDirectory: imageDirectory,
            blockSyntaxes: blockSyntaxes,
            inlineSyntaxes: inlineSyntaxes,
            extensionSet: extensionSet,
            imageBuilder: imageBuilder,
            checkboxBuilder: checkboxBuilder,
            builders: builders,
            listItemCrossAxisAlignment: listItemCrossAxisAlignment,
            bulletBuilder: bulletBuilder,
            commentBubbleBuilder: commentBubbleBuilder,
            selectedBackgroundColor: selectedBackgroundColor);

  /// See [ScrollView.shrinkWrap]
  final bool shrinkWrap;

  /// Whether to allow the widget to fit the child content.
  final bool fitContent;

  final Color selectedBackgroundColor;

  @override
  Widget build(BuildContext context, List<Widget>? children) {
    if (children!.length == 1) return children.single;
    return Column(
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment:
          fitContent ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// A scrolling widget that parses and displays Markdown.
///
/// Supports all GitHub Flavored Markdown from the
/// [specification](https://github.github.com/gfm/).
///
/// See also:
///
///  * [MarkdownBody], which is a non-scrolling container of Markdown.
///  * <https://github.github.com/gfm/>
class Markdown extends MarkdownWidget {
  /// Creates a scrolling widget that parses and displays Markdown.
  const Markdown(
      {Key? key,
      String? data,
      List<md.Node>? nodes,
      bool selectable = false,
      MarkdownStyleSheet? styleSheet,
      MarkdownStyleSheetBaseTheme? styleSheetTheme,
      SyntaxHighlighter? syntaxHighlighter,
      TextStyle? highLightStyle,
      MarkdownTapLinkCallback? onTapLink,
      MarkdownLongPressCallback? longPressCallback,
      VoidCallback? onTapText,
      String? imageDirectory,
      List<md.BlockSyntax>? blockSyntaxes,
      List<md.InlineSyntax>? inlineSyntaxes,
      md.ExtensionSet? extensionSet,
      MarkdownImageBuilder? imageBuilder,
      MarkdownCheckboxBuilder? checkboxBuilder,
      MarkdownBulletBuilder? bulletBuilder,
      Map<String, MarkdownElementBuilder> builders = const {},
      MarkdownListItemCrossAxisAlignment listItemCrossAxisAlignment =
          MarkdownListItemCrossAxisAlignment.baseline,
      ParagraphPressEditCallBack? paragraphPressEditCallBack,
      CommentBubbleBuilder? commentBubbleBuilder,
      ContentTapCallBack? contentTapCallBack,
      LongPressCallBack? longPressCallBack,
      Color? selectedBackgroundColor,
      this.padding = const EdgeInsets.all(16.0),
      this.controller,
      this.physics,
      this.shrinkWrap = false,
      this.alignment,
      this.bottomView})
      : super(
            key: key,
            data: data,
            nodes: nodes,
            selectable: selectable,
            styleSheet: styleSheet,
            styleSheetTheme: styleSheetTheme,
            syntaxHighlighter: syntaxHighlighter,
            highLightStyle: highLightStyle,
            onTapLink: onTapLink,
            longPressCallback: longPressCallback,
            onTapText: onTapText,
            imageDirectory: imageDirectory,
            blockSyntaxes: blockSyntaxes,
            inlineSyntaxes: inlineSyntaxes,
            extensionSet: extensionSet,
            imageBuilder: imageBuilder,
            checkboxBuilder: checkboxBuilder,
            builders: builders,
            listItemCrossAxisAlignment: listItemCrossAxisAlignment,
            bulletBuilder: bulletBuilder,
            paragraphPressEditCallBack: paragraphPressEditCallBack,
            contentTapCallBack: contentTapCallBack,
            longPressCallBack: longPressCallBack,
            commentBubbleBuilder: commentBubbleBuilder,
            selectedBackgroundColor:
                selectedBackgroundColor ?? Colors.transparent,
            bottomView: bottomView);

  /// The amount of space by which to inset the children.
  final EdgeInsets padding;

  final Widget? bottomView;

  /// An object that can be used to control the position to which this scroll view is scrolled.
  ///
  /// See also: [ScrollView.controller]
  final ScrollController? controller;

  /// How the scroll view should respond to user input.
  ///
  /// See also: [ScrollView.physics]
  final ScrollPhysics? physics;

  /// Whether the extent of the scroll view in the scroll direction should be
  /// determined by the contents being viewed.
  ///
  /// See also: [ScrollView.shrinkWrap]
  final bool shrinkWrap;

  final MainAxisAlignment? alignment;

  bool get _reverse => alignment == MainAxisAlignment.end;

  @override
  Widget build(BuildContext context, List<Widget>? children) {
    if (children!.length == 1) return children.single;
    return ListView.builder(
      padding: padding,
      controller: controller,
      physics: physics,
      shrinkWrap: shrinkWrap,
      reverse: _reverse,
      itemCount: children.length,
      itemBuilder: (BuildContext context, int index) {
        return children[_reverse ? children.length - 1 - index : index];
      },
    );
  }
}

/// Parse [task list items](https://github.github.com/gfm/#task-list-items-extension-).
class TaskListSyntax extends md.InlineSyntax {
  // FIXME: Waiting for dart-lang/markdown#269 to land
  static final String _pattern = r'^ *\[([ xX])\] +';

  TaskListSyntax() : super(_pattern);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    md.Element el = md.Element.withTag('input');
    el.attributes['type'] = 'checkbox';
    el.attributes['disabled'] = 'true';
    el.attributes['checked'] = '${match[1]!.trim().isNotEmpty}';
    parser.addNode(el);
    return true;
  }
}
