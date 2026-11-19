import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui.dart';

/// Full-screen editor to cut a part out of the uploaded result (a photo, or
/// the pages of a PDF). Drag the frame to move it, the corners to resize it.
/// The cut is made at the image's full resolution and handed to
/// `app.addCrop` as PNG bytes.
class CropEditor extends StatefulWidget {
  const CropEditor({super.key});

  @override
  State<CropEditor> createState() => _CropEditorState();
}

class _CropEditorState extends State<CropEditor> {
  int page = 0;
  ui.Image? image;
  // the frame, as fractions of the image (0..1)
  Rect frame = const Rect.fromLTRB(.08, .08, .92, .6);
  bool cutting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pages = AppScope.read(context).cropper!.$2;
    final img = await decodeImageFromList(pages[page]);
    if (!mounted) return;
    setState(() {
      image = img;
      frame = const Rect.fromLTRB(.08, .08, .92, .6);
    });
  }

  void _goto(int i) {
    setState(() {
      page = i;
      image = null;
    });
    _load();
  }

  Future<void> _cut() async {
    final img = image;
    if (img == null || cutting) return;
    setState(() => cutting = true);
    final src = Rect.fromLTRB(
      frame.left * img.width, frame.top * img.height,
      frame.right * img.width, frame.bottom * img.height,
    );
    final rec = ui.PictureRecorder();
    Canvas(rec).drawImageRect(img, src, Rect.fromLTWH(0, 0, src.width, src.height), Paint()..filterQuality = FilterQuality.high);
    final out = await rec.endRecording().toImage(src.width.round(), src.height.round());
    final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    setState(() => cutting = false);
    if (bytes != null) AppScope.read(context).addCrop(bytes.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final pages = app.cropper!.$2;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Positioned.fill(
      child: Material(
        color: const Color(0xF20B0B0C),
        child: Column(
          children: [
            SizedBox(height: top + 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Tap(
                    onTap: app.closeCropper,
                    child: const Padding(padding: EdgeInsets.all(8), child: LIcon('X', size: 22, color: Colors.white)),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(app.tr('قص جزء من النتيجة', 'بڕینی بەشێک', 'Crop part of the result'),
                            style: ts(context, 16, weight: w700, color: Colors.white)),
                        Text(app.tr('اسحب الإطار والزوايا لتحديد الجزء', 'چوارچێوە و گۆشەکان ڕابکێشە', 'Drag the frame and its corners'),
                            style: ts(context, 11.5, color: Colors.white60)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: image == null
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(builder: (context, box) {
                        final img = image!;
                        final scale = [box.maxWidth / img.width, box.maxHeight / img.height].reduce((a, b) => a < b ? a : b);
                        final w = img.width * scale, h = img.height * scale;
                        return Center(
                          child: SizedBox(
                            width: w,
                            height: h,
                            child: _FrameArea(
                              size: Size(w, h),
                              frame: frame,
                              onChanged: (r) => setState(() => frame = r),
                              child: RawImage(image: img, width: w, height: h, fit: BoxFit.fill),
                            ),
                          ),
                        );
                      }),
                    ),
            ),
            if (pages.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _round('ChevronRight', page > 0 ? () => _goto(page - 1) : null, flip: !app.rtl),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('${app.tr('صفحة', 'لاپەڕە', 'Page')} ${page + 1} / ${pages.length}',
                        style: ts(context, 13, weight: w700, color: Colors.white)),
                  ),
                  _round('ChevronLeft', page < pages.length - 1 ? () => _goto(page + 1) : null, flip: !app.rtl),
                ],
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
              child: Row(
                children: [
                  Expanded(
                    child: Tap(
                      onTap: app.closeCropper,
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(999)),
                        child: Text(app.tr('تخطي', 'تێپەڕاندن', 'Skip'), style: ts(context, 15, weight: w700, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Tap(
                      onTap: image == null ? null : _cut,
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: pal.accent, borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const LIcon('Check', size: 18, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(cutting ? '…' : app.tr('قص وإضافة للتقرير', 'بڕین و زیادکردن', 'Crop and add to report'),
                                style: ts(context, 15, weight: w700, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _round(String icon, VoidCallback? onTap, {bool flip = false}) => Tap(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .3 : 1,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
            child: LIcon(icon, size: 18, color: Colors.white, flipX: flip),
          ),
        ),
      );
}

/// The image with a movable, resizable frame; outside the frame is dimmed.
class _FrameArea extends StatefulWidget {
  final Size size;
  final Rect frame;
  final ValueChanged<Rect> onChanged;
  final Widget child;
  const _FrameArea({required this.size, required this.frame, required this.onChanged, required this.child});

  @override
  State<_FrameArea> createState() => _FrameAreaState();
}

class _FrameAreaState extends State<_FrameArea> {
  /// 'move' or a corner: 'tl', 'tr', 'bl', 'br'.
  String? _grab;
  static const _min = .06;

  Rect get _px => Rect.fromLTRB(
        widget.frame.left * widget.size.width, widget.frame.top * widget.size.height,
        widget.frame.right * widget.size.width, widget.frame.bottom * widget.size.height,
      );

  void _start(Offset p) {
    final r = _px;
    const reach = 28.0;
    final corners = {'tl': r.topLeft, 'tr': r.topRight, 'bl': r.bottomLeft, 'br': r.bottomRight};
    for (final e in corners.entries) {
      if ((e.value - p).distance <= reach) {
        _grab = e.key;
        return;
      }
    }
    _grab = r.inflate(6).contains(p) ? 'move' : null;
  }

  void _update(Offset delta) {
    if (_grab == null) return;
    final dx = delta.dx / widget.size.width, dy = delta.dy / widget.size.height;
    var f = widget.frame;
    switch (_grab) {
      case 'move':
        final mx = dx.clamp(-f.left, 1 - f.right), my = dy.clamp(-f.top, 1 - f.bottom);
        f = f.shift(Offset(mx, my));
      case 'tl':
        f = Rect.fromLTRB((f.left + dx).clamp(0, f.right - _min), (f.top + dy).clamp(0, f.bottom - _min), f.right, f.bottom);
      case 'tr':
        f = Rect.fromLTRB(f.left, (f.top + dy).clamp(0, f.bottom - _min), (f.right + dx).clamp(f.left + _min, 1), f.bottom);
      case 'bl':
        f = Rect.fromLTRB((f.left + dx).clamp(0, f.right - _min), f.top, f.right, (f.bottom + dy).clamp(f.top + _min, 1));
      case 'br':
        f = Rect.fromLTRB(f.left, f.top, (f.right + dx).clamp(f.left + _min, 1), (f.bottom + dy).clamp(f.top + _min, 1));
    }
    widget.onChanged(f);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => _start(d.localPosition),
      onPanUpdate: (d) => _update(d.delta),
      onPanEnd: (_) => _grab = null,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(child: CustomPaint(painter: _FramePainter(_px))),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  final Rect r;
  _FramePainter(this.r);

  @override
  void paint(Canvas canvas, Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRect(r);
    canvas.drawPath(Path.combine(PathOperation.difference, all, hole), Paint()..color = const Color(0x99000000));
    canvas.drawRect(r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white);
    // rule-of-thirds guides
    final guide = Paint()
      ..color = Colors.white38
      ..strokeWidth = .8;
    for (var i = 1; i < 3; i++) {
      final x = r.left + r.width * i / 3, y = r.top + r.height * i / 3;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), guide);
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), guide);
    }
    // corner handles
    final h = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const l = 16.0;
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      final sx = c.dx == r.left ? 1.0 : -1.0, sy = c.dy == r.top ? 1.0 : -1.0;
      canvas.drawLine(c, c + Offset(l * sx, 0), h);
      canvas.drawLine(c, c + Offset(0, l * sy), h);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.r != r;
}
