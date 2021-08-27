import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum PressType {
  longPress,
  singleClick,
}

enum PreferredPosition {
  top,
  bottom,
}

typedef MenuVisibleChange = Function(bool?);

typedef ContentTapCallBack = Function(bool?);

class CustomPopupMenuController extends ChangeNotifier {
  bool menuIsShowing = false;

  void showMenu() {
    menuIsShowing = true;
    debugPrint("-controller showMenu");
    notifyListeners();
  }

  void hideMenu() {
    menuIsShowing = false;
    debugPrint("-controller hideMenu");
    notifyListeners();
  }

  void toggleMenu() {
    menuIsShowing = !menuIsShowing;
    notifyListeners();
  }
}

class CustomPopupMenu extends StatefulWidget {
  CustomPopupMenu({required this.child,
    required this.menuBuilder,
    required this.pressType,
    this.controller,
    this.arrowColor = const Color(0xFF4C4C4C),
    this.showArrow = true,
    this.barrierColor = Colors.black12,
    this.arrowSize = 10.0,
    this.horizontalMargin = 10.0,
    this.verticalMargin = 10.0,
    this.position,
    this.menuVisibleChange,
    this.contentTapCallBack});

  final Widget child;
  final PressType pressType;
  final bool showArrow;
  final Color arrowColor;
  final Color barrierColor;
  final double horizontalMargin;
  final double verticalMargin;
  final double arrowSize;
  final CustomPopupMenuController? controller;
  final Widget Function() menuBuilder;
  final PreferredPosition? position;
  final MenuVisibleChange? menuVisibleChange;
  final ContentTapCallBack? contentTapCallBack;

  @override
  _CustomPopupMenuState createState() => _CustomPopupMenuState();
}

class _CustomPopupMenuState extends State<CustomPopupMenu> {
  RenderBox? _childBox;
  RenderBox? _parentBox;
  OverlayEntry? _overlayEntry;
  CustomPopupMenuController? _controller;
  bool? showMenu;

  _showMenu() {
    Widget arrow = ClipPath(
      child: Container(
        width: widget.arrowSize,
        height: widget.arrowSize,
        color: widget.arrowColor,
      ),
      clipper: _ArrowClipper(),
    );

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: <Widget>[
            GestureDetector(
              onTap: () {
                _hideMenu();
                debugPrint("widget.contentTapCallBack--${widget.contentTapCallBack}");
                if (widget.contentTapCallBack != null) {
                  widget.contentTapCallBack!(false);
                }
              },
              child: Container(
                color: widget.barrierColor,
              ),
            ),
            Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth:
                  _parentBox!.size.width - 2 * widget.horizontalMargin,
                  minWidth: 0,
                ),
                child: CustomMultiChildLayout(
                  delegate: _MenuLayoutDelegate(
                    anchorSize: _childBox!.size,
                    anchorOffset: _childBox!.localToGlobal(
                      Offset(-widget.horizontalMargin, 0),
                    ),
                    verticalMargin: widget.verticalMargin,
                    position: widget.position,
                  ),
                  children: <Widget>[
                    if (widget.showArrow)
                      LayoutId(
                        id: _MenuLayoutId.arrow,
                        child: arrow,
                      ),
                    if (widget.showArrow)
                      LayoutId(
                        id: _MenuLayoutId.downArrow,
                        child: Transform.rotate(
                          angle: math.pi,
                          child: arrow,
                        ),
                      ),
                    LayoutId(
                      id: _MenuLayoutId.content,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Material(
                            child: widget.menuBuilder(),
                            color: Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
    if (_overlayEntry != null) {
      Overlay.of(context)!.insert(_overlayEntry!);
    }
    showMenu = true;
    widget.menuVisibleChange!(showMenu);
  }

  _hideMenu() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    showMenu = false;
    widget.menuVisibleChange!(showMenu);
  }

  _updateView() {
    debugPrint("_controller.menuIsShowing${_controller?.menuIsShowing}");
    if (_controller?.menuIsShowing ?? false) {
      _showMenu();
    } else {
      _hideMenu();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    debugPrint("_controller$_controller");
    if (_controller == null) _controller = CustomPopupMenuController();
    _controller?.addListener(_updateView);
    WidgetsBinding.instance?.addPostFrameCallback((call) {
      if (mounted) {
        _childBox = context.findRenderObject() as RenderBox?;
        _parentBox =
        Overlay
            .of(context)
            ?.context
            .findRenderObject() as RenderBox?;
      }
    });
  }

  @override
  void dispose() {
    _hideMenu();
    _controller?.removeListener(_updateView);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var child = Material(
      child: InkWell(
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: widget.child,
        onTap: () {
          if (widget.pressType == PressType.singleClick) {
            _showMenu();
          }
          if (widget.contentTapCallBack != null) {
            debugPrint("widget.contentTapCallBack onTap");
            widget.contentTapCallBack!(true);
          }
        },
        onLongPress: () {
          if (widget.pressType == PressType.longPress) {
            _showMenu();
          }
        },
      ),
      color: Colors.transparent,
    );
    if (Platform.isIOS) {
      return child;
    } else {
      return WillPopScope(
        onWillPop: () {
          _hideMenu();
          return Future.value(true);
        },
        child: child,
      );
    }
  }
}

enum _MenuLayoutId {
  arrow,
  downArrow,
  content,
}

enum _MenuPosition {
  bottomLeft,
  bottomCenter,
  bottomRight,
  topLeft,
  topCenter,
  topRight,
  center,
}

class _MenuLayoutDelegate extends MultiChildLayoutDelegate {
  _MenuLayoutDelegate({
    required this.anchorSize,
    required this.anchorOffset,
    required this.verticalMargin,
    this.position,
  });

  final Size anchorSize;
  final Offset anchorOffset;
  final double verticalMargin;
  final PreferredPosition? position;

  @override
  void performLayout(Size size) {
    Size contentSize = Size.zero;
    Size arrowSize = Size.zero;
    Offset contentOffset = Offset(0, 0);
    Offset arrowOffset = Offset(0, 0);

    double anchorCenterX = anchorOffset.dx + anchorSize.width / 2;
    double anchorTopY = anchorOffset.dy;
    double anchorBottomY = anchorTopY + anchorSize.height;
    _MenuPosition menuPosition = _MenuPosition.bottomCenter;

    if (hasChild(_MenuLayoutId.content)) {
      contentSize = layoutChild(
        _MenuLayoutId.content,
        BoxConstraints.loose(size),
      );
    }
    if (hasChild(_MenuLayoutId.arrow)) {
      arrowSize = layoutChild(
        _MenuLayoutId.arrow,
        BoxConstraints.loose(size),
      );
    }
    if (hasChild(_MenuLayoutId.downArrow)) {
      layoutChild(
        _MenuLayoutId.downArrow,
        BoxConstraints.loose(size),
      );
    }

    bool isTop = false;

    if (anchorBottomY >=
        size.height -
            contentSize.height -
            arrowSize.height -
            verticalMargin &&
        anchorTopY <= contentSize.height + arrowSize.height + verticalMargin) {
      menuPosition = _MenuPosition.topCenter;
    } else {}

    if (anchorTopY > contentSize.height + arrowSize.height + verticalMargin) {
      menuPosition = _MenuPosition.topCenter;
    } else if (anchorBottomY <
        size.height - contentSize.height - arrowSize.height - verticalMargin) {
      menuPosition = _MenuPosition.bottomCenter;
    } else {
      menuPosition = _MenuPosition.center;
    }

    switch (menuPosition) {
      case _MenuPosition.bottomCenter:
        arrowOffset = Offset(
          anchorCenterX - arrowSize.width / 2,
          anchorBottomY + verticalMargin,
        );
        contentOffset = Offset(
          anchorCenterX - contentSize.width / 2,
          anchorBottomY + verticalMargin + arrowSize.height,
        );
        break;
      case _MenuPosition.bottomLeft:
        arrowOffset = Offset(anchorCenterX - arrowSize.width / 2,
            anchorBottomY + verticalMargin);
        contentOffset = Offset(
          0,
          anchorBottomY + verticalMargin + arrowSize.height,
        );
        break;
      case _MenuPosition.bottomRight:
        arrowOffset = Offset(anchorCenterX - arrowSize.width / 2,
            anchorBottomY + verticalMargin);
        contentOffset = Offset(
          size.width - contentSize.width,
          anchorBottomY + verticalMargin + arrowSize.height,
        );
        break;
      case _MenuPosition.topCenter:
        arrowOffset = Offset(
          anchorCenterX - arrowSize.width / 2,
          anchorTopY - verticalMargin - arrowSize.height,
        );
        contentOffset = Offset(
          anchorCenterX - contentSize.width / 2,
          anchorTopY - verticalMargin - arrowSize.height - contentSize.height,
        );
        break;
      case _MenuPosition.topLeft:
        arrowOffset = Offset(
          anchorCenterX - arrowSize.width / 2,
          anchorTopY - verticalMargin - arrowSize.height,
        );
        contentOffset = Offset(
          0,
          anchorTopY - verticalMargin - arrowSize.height - contentSize.height,
        );
        break;
      case _MenuPosition.topRight:
        arrowOffset = Offset(
          anchorCenterX - arrowSize.width / 2,
          anchorTopY - verticalMargin - arrowSize.height,
        );
        contentOffset = Offset(
          size.width - contentSize.width,
          anchorTopY - verticalMargin - arrowSize.height - contentSize.height,
        );
        break;
      case _MenuPosition.center:
        arrowOffset = Offset(
          anchorCenterX - arrowSize.width / 2,
          size.height / 2 + contentSize.height,
        );
        contentOffset = Offset(
          anchorCenterX - contentSize.width / 2,
          size.height / 2,
        );
        break;
    }
    if (hasChild(_MenuLayoutId.content)) {
      positionChild(_MenuLayoutId.content, contentOffset);
    }
    bool isBottom = false;
    if (_MenuPosition.values.indexOf(menuPosition) < 3) {
      // bottom
      isBottom = true;
    }
    if (hasChild(_MenuLayoutId.arrow)) {
      positionChild(
        _MenuLayoutId.arrow,
        isBottom
            ? Offset(arrowOffset.dx, arrowOffset.dy + 0.1)
            : Offset(-100, 0),
      );
    }
    if (hasChild(_MenuLayoutId.downArrow)) {
      positionChild(
        _MenuLayoutId.downArrow,
        !isBottom
            ? Offset(arrowOffset.dx, arrowOffset.dy - 0.1)
            : Offset(-100, 0),
      );
    }
  }

  @override
  bool shouldRelayout(MultiChildLayoutDelegate oldDelegate) => false;
}

class _ArrowClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width / 2, size.height / 2);
    path.lineTo(size.width, size.height);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return true;
  }
}
