import 'package:flutter/material.dart';

import '../app_state.dart';
import '../ui.dart';
import 'scan_screen.dart';

/// "Send to Other Labs": send a referral, receive B2B samples, track shipments.
class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  late final TextEditingController _patient;
  late final TextEditingController _test;
  late final TextEditingController _lab;
  late final TextEditingController _barcode;
  late final TextEditingController _age = TextEditingController(text: AppScope.read(context).refAge);
  final _price = TextEditingController();

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    _patient = TextEditingController(text: app.refPatient);
    _test = TextEditingController(text: app.refTestSearch);
    _lab = TextEditingController(text: app.refLabSearch);
    _barcode = TextEditingController(text: app.barcode);
  }

  @override
  void dispose() {
    for (final c in [_patient, _test, _lab, _barcode, _price, _age]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final w = app.w, d = app.d;
    if (_barcode.text != app.barcode) _barcode.text = app.barcode;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        112 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(w('sendTitle'), style: ts(context, 28, weight: w700)),
          Text(w('sendSub'), style: ts(context, 13, color: pal.muted)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: pal.segmented,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                for (final t in [
                  ('send', d('sendTab')),
                  ('receive', d('receiveTab')),
                ])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => app.updateSend(() => app.sendTab = t.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: app.sendTab == t.$1 ? pal.ink : null,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t.$2,
                          style: ts(
                            context,
                            13,
                            weight: w700,
                            color: app.sendTab == t.$1
                                ? (pal.dark
                                      ? const Color(0xFF0B0B0D)
                                      : pal.appBg)
                                : pal.muted2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (app.sendTab == 'receive')
            ..._receive(context)
          else
            ..._send(context),
        ],
      ),
    );
  }

  List<Widget> _receive(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final d = app.d;
    final s = app.foundSample;
    return [
      const SizedBox(height: 12),
      CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(d('receiveTitle'), style: ts(context, 15, weight: w700)),
            const SizedBox(height: 12),
            SearchBarBox(
              icon: 'Barcode',
              iconSize: 17,
              controller: _barcode,
              hint: d('barcodeHint'),
              onChanged: app.setBarcode,
            ),
            const SizedBox(height: 12),
            Tap(
              onTap: () async {
                final code = await ScanScreen.open(context);
                if (code == null || code.isEmpty) return;
                _barcode.text = code;
                app.setBarcode(code);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: pal.chipBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: pal.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LIcon('ScanLine', size: 17, color: pal.ink),
                    const SizedBox(width: 8),
                    Text(
                      app.tr('مسح بالكاميرا', 'سکان بە کامێرا', 'Scan with camera'),
                      style: ts(context, 16, weight: w700),
                    ),
                  ],
                ),
              ),
            ),
            if (s != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.chipBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: pal.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${d('sampleFound')}: ${s.code}',
                      style: ts(context, 13, weight: w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.patient} • ${s.test}',
                      style: ts(context, 13, color: pal.muted2),
                    ),
                    Text(
                      '${d('sendingLab')}: ${s.lab} • ${s.status}',
                      style: ts(context, 12, color: pal.muted),
                    ),
                    const SizedBox(height: 12),
                    Tap(
                      onTap: app.confirmReceive,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: pal.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          d('confirmReceive'),
                          style: ts(
                            context,
                            16,
                            weight: w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      if (app.receivedSamples.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(d('receivedList'), style: ts(context, 16, weight: w700)),
        for (final r in app.receivedSamples) ...[
          const SizedBox(height: 8),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.patient} • ${r.test}',
                  style: ts(context, 16, weight: w700),
                ),
                Text(
                  '${r.code} • ${r.lab} • ${r.status}',
                  style: ts(context, 12, color: pal.muted),
                ),
              ],
            ),
          ),
        ],
      ],
    ];
  }

  List<Widget> _send(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final w = app.w, d = app.d;

    Widget stepTitle(String n, String text) =>
        Text('$n. $text', style: ts(context, 15, weight: w700));

    final typingLab = app.refLabSearch.trim().isNotEmpty && app.refLabOpen;
    final labCards = typingLab
        ? app.refLabMatches
        : app.partnerLabs.where((l) => l.name == app.refLab).toList();
    final labDropdownItems = <Widget>[
      if (app.refLabSearch.trim().isNotEmpty &&
          app.refLabMatches.isEmpty &&
          !app.partnerLabs.any(
            (l) =>
                l.name.toLowerCase() == app.refLabSearch.trim().toLowerCase(),
          ))
        DropdownRow(
          label: '${d('useNewLab')}: ${app.refLabSearch.trim()}',
          color: pal.accent,
          weight: w700,
          onTap: app.useTypedLab,
        ),
    ];

    return [
      const SizedBox(height: 12),
      CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            stepTitle('1', w('chooseName')),
            Text(w('chooseNameHint'), style: ts(context, 12, color: pal.muted)),
            const SizedBox(height: 8),
            FloatingDropdown(
              open: app.refPatientOpen && app.refPatient.trim().isNotEmpty && app.refPatientMatches.isNotEmpty,
              items: [
                for (final p in app.refPatientMatches)
                  DropdownRow(
                    label: p.name,
                    onTap: () {
                      _patient.text = p.name;
                      app.pickRefPatient(p);
                      _age.text = app.refAge;
                      FocusScope.of(context).unfocus();
                    },
                  ),
              ],
              child: SearchBarBox(
                controller: _patient,
                hint: w('chooseName'),
                onChanged: (v) => app.updateSend(() {
                  app.refPatient = v;
                  app.refPatientOpen = true;
                }),
              ),
            ),
            const SizedBox(height: 8),
            // Gender and age (filled in from a saved patient; typed for a new name).
            Row(
              children: [
                Text(w('age'), style: ts(context, 12, weight: w700, color: pal.muted)),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: BoxField(
                      controller: _age,
                      hint: '25',
                      vPad: 10,
                      ltr: true,
                      keyboard: TextInputType.number,
                      onChanged: (v) => app.updateSend(() => app.refAge = v.replaceAll(RegExp(r'[^0-9]'), '')),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(app.tr('سنة', 'ساڵ', 'yrs'), style: ts(context, 12, weight: w700, color: pal.muted)),
                const SizedBox(width: 10),
                for (final g in const [('Male', 'Mars', Color(0xFF5B7A99)), ('Female', 'Venus', Color(0xFFB0708A))]) ...[
                  GestureDetector(
                    onTap: () => app.updateSend(() => app.refGender = g.$1),
                    child: Container(
                      width: 38,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: app.refGender == g.$1 ? pal.accent : pal.chipBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: pal.cardBorder),
                      ),
                      child: LIcon(g.$2, size: 15, strokeWidth: 2.2, color: app.refGender == g.$1 ? Colors.white : g.$3),
                    ),
                  ),
                  if (g.$1 == 'Male') const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 16),
            stepTitle('2', w('chooseTest')),
            const SizedBox(height: 8),
            FloatingDropdown(
              open: app.refTestOpen && app.refTestSearch.trim().isNotEmpty && app.refTestMatches.isNotEmpty,
              items: [
                for (final t in app.refTestMatches)
                  DropdownRow(
                    label: t.name,
                    onTap: () {
                      _test.clear();
                      app.addRefTest(t.name);
                    },
                  ),
              ],
              child: SearchBarBox(
                controller: _test,
                hint: w('searchTests'),
                onChanged: (v) => app.updateSend(() {
                  app.refTestSearch = v;
                  app.refTestOpen = true;
                }),
              ),
            ),
            if (app.refTests.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in app.refTests)
                    Container(
                      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: pal.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t,
                            style: ts(context, 12, weight: w700, color: Colors.white),
                          ),
                          const SizedBox(width: 4),
                          Tap(
                            onTap: () => app.removeRefTest(t),
                            child: Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .25),
                                shape: BoxShape.circle,
                              ),
                              child: const LIcon('X', size: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            stepTitle('3', w('destinationLab')),
            const SizedBox(height: 8),
            FloatingDropdown(
              open: typingLab && labDropdownItems.isNotEmpty,
              items: labDropdownItems,
              child: SearchBarBox(
                controller: _lab,
                hint: d('labSearchPh'),
                onSubmitted: (_) => app.useTypedLab(),
                onChanged: (v) => app.updateSend(() {
                  app.refLabSearch = v;
                  app.refLabOpen = true;
                }),
              ),
            ),
            for (final l in labCards) ...[
              const SizedBox(height: 8),
              Tap(
                onTap: () {
                  _lab.clear();
                  FocusScope.of(context).unfocus();
                  app.updateSend(() {
                    app.refLab = l.name;
                    app.refLabSearch = '';
                    app.refLabOpen = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: pal.card,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: app.refLab == l.name ? pal.accent : pal.cardBorder,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: pal.chipBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: LIcon('Building2', size: 19, color: pal.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ts(context, 16, weight: w700),
                            ),
                            Text(
                              '${l.city} • ${l.dist}',
                              style: ts(context, 12, color: pal.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '★ ${l.rating}',
                            style: ts(context, 13, weight: w700),
                          ),
                          Text(
                            app.labPriceText(l),
                            style: ts(context, 11, color: pal.muted),
                          ),
                        ],
                      ),
                      if (app.refLab == l.name) ...[
                        const SizedBox(width: 12),
                        LIcon('Check', size: 18, color: pal.accent),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            // Price: the receiving lab's B2B price, editable.
            if (app.refPrice.isNotEmpty || app.refLabObj?.id.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                '${app.tr('السعر', 'نرخ', 'Price')} (${app.currency})',
                style: ts(context, 13, weight: w700, color: pal.muted2),
              ),
              const SizedBox(height: 6),
              Builder(builder: (context) {
                if (_price.text != app.refPrice) {
                  _price.value = TextEditingValue(
                    text: app.refPrice,
                    selection: TextSelection.collapsed(offset: app.refPrice.length),
                  );
                }
                return SearchBarBox(
                  icon: 'Pencil',
                  controller: _price,
                  hint: app.tr('اكتب السعر', 'نرخ بنووسە', 'Type the price'),
                  onChanged: app.setRefPrice,
                );
              }),
            ],
            const SizedBox(height: 16),
            Tap(
              onTap: app.sendReferral,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: pal.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const LIcon('Send', size: 17, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      '4. ${w('send')}',
                      style: ts(context, 16, weight: w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(w('trackingTitle'), style: ts(context, 16, weight: w700)),
      for (final r in app.referrals) ...[
        const SizedBox(height: 8),
        Tap(
          onTap: () => app.showLabel(r),
          child: CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${r.patient} • ${r.test}',
                        style: ts(context, 16, weight: w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: pal.softAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        r.status,
                        style: ts(
                          context,
                          11,
                          weight: w700,
                          color: pal.accent,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${r.lab} • ${w('eta')}: ${r.eta}',
                  style: ts(context, 12, color: pal.muted),
                ),
                Text(
                  '${w('trackingId')}: ${r.tracking}',
                  style: ts(context, 12, color: pal.muted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: i <= r.step ? pal.accent : pal.track,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i < 3) ...[
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: i < r.step ? pal.accent : pal.track,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${w('timeline')} • ${d('labelTitle')} →',
                  style: ts(context, 11, color: pal.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }
}
