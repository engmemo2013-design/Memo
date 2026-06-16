// ميمو — Memo | Asset Handover & Return  (single-file build for phone/GitHub)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:google_fonts/google_fonts.dart';

// ===== lib/theme.dart =====
/// memo brand palette — navy matches the official Handover/Return forms.
class AppColors {
  static const navy = Color(0xFF1E4E8C);
  static const navyDark = Color(0xFF16365F);
  static const amber = Color(0xFFF59E0B);
  static const amberDark = Color(0xFFD97706);
  static const bg = Color(0xFFF1F5F9);
  static const card = Colors.white;
  static const line = Color(0xFFE2E8F0);
  static const ink = Color(0xFF0F172A);
  static const sub = Color(0xFF64748B);
  static const soft = Color(0xFFF8FAFC);
  static const ok = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    primary: AppColors.navy,
    secondary: AppColors.amber,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navyDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0x1F1E4E8C),
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
      iconTheme: MaterialStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(MaterialState.selected) ? AppColors.navy : AppColors.sub,
        ),
      ),
    ),
    dividerColor: AppColors.line,
  );
}

// ===== lib/models.dart =====
/// Operation type. ("return" is a reserved word, so we use `ret`.)
enum OpType { handover, ret }

/// ---------------------------------------------------------------------------
/// Device catalog — exactly the types the client requested (+ Other).
/// ---------------------------------------------------------------------------
class DeviceType {
  final String id;
  final String ar;
  final String en;
  final IconData icon;
  const DeviceType(this.id, this.ar, this.en, this.icon);
}

const List<DeviceType> kDevices = [
  DeviceType('laptop', 'لاب توب', 'Laptop', Icons.laptop_mac),
  DeviceType('pc', 'كمبيوتر مكتبي PC', 'Desktop PC', Icons.desktop_windows),
  DeviceType('speaker', 'سماعة (مكبر صوت)', 'Speaker', Icons.speaker),
  DeviceType('mouse_wired', 'ماوس سلكي', 'Wired Mouse', Icons.mouse),
  DeviceType('mouse_wl', 'ماوس لاسلكي', 'Wireless Mouse', Icons.mouse_outlined),
  DeviceType('kb_wired', 'كيبورد سلكي', 'Wired Keyboard', Icons.keyboard),
  DeviceType('kb_wl', 'كيبورد لاسلكي', 'Wireless Keyboard', Icons.keyboard_outlined),
  DeviceType('headset', 'سماعة رأس', 'Headset', Icons.headset_mic),
  DeviceType('monitor', 'شاشة', 'Monitor', Icons.monitor),
  DeviceType('charger', 'شاحن موبايل', 'Phone Charger', Icons.power),
  DeviceType('data_cable', 'كابل بيانات', 'Data Cable', Icons.usb),
  DeviceType('power_cable', 'كابل باور', 'Power Cable', Icons.electrical_services),
  DeviceType('screen_cable', 'كابل شاشة', 'Display Cable', Icons.cable),
  DeviceType('hdmi_dp', 'محول HDMI ← DisplayPort', 'HDMI → DP Adapter', Icons.settings_input_hdmi),
  DeviceType('other', 'أخرى', 'Other', Icons.devices_other),
];

DeviceType deviceById(String id) =>
    kDevices.firstWhere((d) => d.id == id, orElse: () => kDevices.last);

/// ---------------------------------------------------------------------------
/// One row in the assets table: Item-Model / SN / Q / Remarks.
/// ---------------------------------------------------------------------------
class DeviceLine {
  String typeId;
  String model;
  String sn;
  int qty;
  String remarks;
  DeviceLine({
    this.typeId = 'laptop',
    this.model = '',
    this.sn = '',
    this.qty = 1,
    this.remarks = '',
  });

  Map<String, dynamic> toJson() =>
      {'t': typeId, 'm': model, 's': sn, 'q': qty, 'r': remarks};

  factory DeviceLine.fromJson(Map<String, dynamic> j) => DeviceLine(
        typeId: (j['t'] ?? 'other') as String,
        model: (j['m'] ?? '') as String,
        sn: (j['s'] ?? '') as String,
        qty: (j['q'] ?? 1) as int,
        remarks: (j['r'] ?? '') as String,
      );
}

/// ---------------------------------------------------------------------------
/// Employee — registered once, reused for every operation.
/// ---------------------------------------------------------------------------
class Employee {
  final String id;
  String name;
  String code;
  String department;
  String nationalId;
  Employee({
    required this.id,
    this.name = '',
    this.code = '',
    this.department = '',
    this.nationalId = '',
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'code': code, 'dept': department, 'nid': nationalId};

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        department: (j['dept'] ?? '') as String,
        nationalId: (j['nid'] ?? '') as String,
      );
}

/// ---------------------------------------------------------------------------
/// A full Handover / Return operation (one printable form).
/// ---------------------------------------------------------------------------
class AssetRecord {
  final String id;
  OpType type;
  String date; // yyyy-MM-dd
  String assetTransferCode;
  String counterparty; // Handover By / Returned To
  String employeeName;
  String employeeCode;
  String department;
  String nationalId;
  List<DeviceLine> devices;
  int createdAt;

  AssetRecord({
    required this.id,
    required this.type,
    required this.date,
    this.assetTransferCode = '',
    this.counterparty = '',
    this.employeeName = '',
    this.employeeCode = '',
    this.department = '',
    this.nationalId = '',
    required this.devices,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'date': date,
        'atc': assetTransferCode,
        'cp': counterparty,
        'en': employeeName,
        'ec': employeeCode,
        'dept': department,
        'nid': nationalId,
        'dev': devices.map((d) => d.toJson()).toList(),
        'ca': createdAt,
      };

  factory AssetRecord.fromJson(Map<String, dynamic> j) => AssetRecord(
        id: j['id'] as String,
        type: (j['type'] == 'ret') ? OpType.ret : OpType.handover,
        date: (j['date'] ?? '') as String,
        assetTransferCode: (j['atc'] ?? '') as String,
        counterparty: (j['cp'] ?? '') as String,
        employeeName: (j['en'] ?? '') as String,
        employeeCode: (j['ec'] ?? '') as String,
        department: (j['dept'] ?? '') as String,
        nationalId: (j['nid'] ?? '') as String,
        devices: ((j['dev'] ?? []) as List)
            .map((e) => DeviceLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: (j['ca'] ?? 0) as int,
      );
}

// ===== lib/store.dart =====
enum Lang { ar, en }

/// Net assets currently held by one employee.
class Holding {
  final String code;
  final String name;
  final String dept;
  int total = 0;
  final Map<String, int> byType = {};
  Holding(this.code, this.name, this.dept);
}

/// Single global app store. Listenable -> UI rebuilds via AnimatedBuilder.
class AppStore extends ChangeNotifier {
  Lang lang = Lang.ar;
  List<Employee> employees = [];
  List<AssetRecord> records = [];
  bool ready = false;

  bool get isAr => lang == Lang.ar;
  TextDirection get dir => isAr ? TextDirection.rtl : TextDirection.ltr;

  /// Pick the correct language string.
  String tr(String ar, String en) => isAr ? ar : en;

  // ---- persistence -------------------------------------------------------
  static const _kLang = 'memo_lang';
  static const _kEmp = 'memo_employees';
  static const _kRec = 'memo_records';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    lang = (p.getString(_kLang) == 'en') ? Lang.en : Lang.ar;
    final e = p.getString(_kEmp);
    final r = p.getString(_kRec);
    try {
      if (e != null) {
        employees =
            (jsonDecode(e) as List).map((x) => Employee.fromJson(x as Map<String, dynamic>)).toList();
      }
      if (r != null) {
        records =
            (jsonDecode(r) as List).map((x) => AssetRecord.fromJson(x as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // corrupt data — start clean rather than crash
      employees = [];
      records = [];
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLang, lang.name);
    await p.setString(_kEmp, jsonEncode(employees.map((x) => x.toJson()).toList()));
    await p.setString(_kRec, jsonEncode(records.map((x) => x.toJson()).toList()));
  }

  // ---- mutations ---------------------------------------------------------
  void toggleLang() {
    lang = isAr ? Lang.en : Lang.ar;
    _save();
    notifyListeners();
  }

  void addEmployee(Employee e) {
    employees.add(e);
    _save();
    notifyListeners();
  }

  void removeEmployee(String id) {
    employees.removeWhere((x) => x.id == id);
    _save();
    notifyListeners();
  }

  void addRecord(AssetRecord r) {
    records.insert(0, r);
    _save();
    notifyListeners();
  }

  void removeRecord(String id) {
    records.removeWhere((x) => x.id == id);
    _save();
    notifyListeners();
  }

  // ---- derived data ------------------------------------------------------
  /// How many devices each employee currently holds (handover − return).
  Map<String, Holding> holdings() {
    final m = <String, Holding>{};
    for (final r in records) {
      final sign = r.type == OpType.handover ? 1 : -1;
      final key = r.employeeCode.isNotEmpty ? r.employeeCode : r.employeeName;
      final h = m.putIfAbsent(key, () => Holding(r.employeeCode, r.employeeName, r.department));
      for (final d in r.devices) {
        h.total += sign * d.qty;
        h.byType[d.typeId] = (h.byType[d.typeId] ?? 0) + sign * d.qty;
      }
    }
    return m;
  }
}

/// The one instance used everywhere.
final store = AppStore();

String newId() =>
    DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
    (1000 + DateTime.now().microsecond % 9000).toString();

// ===== lib/widgets/common.dart =====
InputDecoration fieldDecoration([String? hint]) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      hintStyle: const TextStyle(color: AppColors.sub, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
      ),
    );

/// A labelled text field used across forms.
class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? hint;
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.sub)),
        const SizedBox(height: 6),
        TextField(
            controller: controller, keyboardType: keyboardType, decoration: fieldDecoration(hint)),
      ],
    );
  }
}

/// A titled white card section.
class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  const SectionCard({super.key, this.title, this.subtitle, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(subtitle!,
                                style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
                          ),
                      ],
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
          ],
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

/// Dashboard metric tile.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const StatCard(
      {super.key,
      required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 24, height: 1)),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.sub),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small gradient "M" logo.
class MemoLogo extends StatelessWidget {
  final double size;
  const MemoLogo({super.key, this.size = 38});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.navy, AppColors.navyDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text('M',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.55)),
    );
  }
}

Widget emptyState(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.sub, fontSize: 14))),
    );

// ===== lib/pdf_service.dart =====
/// Builds and shares/prints the official memo Handover / Return form.
class PdfService {
  static pw.Font? _reg;
  static pw.Font? _bold;

  static Future<void> _ensureFonts() async {
    if (_reg != null && _bold != null) return;
    // الخط بيتجاب وقت التشغيل (مفيش ملفات تتسطّب).
    // لو الـ build اشتكى من الاسم ده، بدّل السطرين بـ:
    //   _reg = await PdfGoogleFonts.notoSansArabicRegular();
    //   _bold = await PdfGoogleFonts.notoSansArabicBold();
    _reg = await PdfGoogleFonts.iBMPlexSansArabicRegular();
    _bold = await PdfGoogleFonts.iBMPlexSansArabicBold();
  }

  static const _navy = PdfColor.fromInt(0xFF1E4E8C);
  static const _grey = PdfColor.fromInt(0xFF64748B);
  static const _border = PdfColor.fromInt(0xFF94A3B8);
  static const _head = PdfColor.fromInt(0xFFF1F5F9);

  static Future<pw.Document> _build(AssetRecord rec) async {
    await _ensureFonts();
    final isH = rec.type == OpType.handover;
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: _reg!, bold: _bold!),
    );

    pw.Widget infoCell(String en, String val) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(
                  text: '$en : ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.TextSpan(text: val, style: const pw.TextStyle(fontSize: 10)),
            ]),
          ),
        );

    pw.Widget cell(String t, {bool header = false, pw.TextAlign align = pw.TextAlign.left}) =>
        pw.Container(
          alignment: align == pw.TextAlign.center
              ? pw.Alignment.center
              : pw.Alignment.centerLeft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          color: header ? _head : null,
          child: pw.Text(t,
              textAlign: align,
              style: pw.TextStyle(
                  fontSize: 9.5, fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );

    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        cell('#', header: true, align: pw.TextAlign.center),
        cell('Item - Model', header: true),
        cell('SN', header: true),
        cell('Q', header: true, align: pw.TextAlign.center),
        cell('Remarks', header: true),
      ]),
    ];
    final list = [...rec.devices];
    final showCount = list.length < 5 ? 5 : list.length;
    for (var i = 0; i < showCount; i++) {
      final d = i < list.length ? list[i] : null;
      final name = d == null ? '' : '${deviceById(d.typeId).ar} ${d.model}'.trim();
      rows.add(pw.TableRow(children: [
        cell('${i + 1}', align: pw.TextAlign.center),
        cell(name),
        cell(d?.sn ?? ''),
        cell(d == null ? '' : '${d.qty}', align: pw.TextAlign.center),
        cell(d?.remarks ?? ''),
      ]));
    }

    final declaration = isH
        ? 'أقر بموجب هذا بأنني استلمت الأصول المذكورة أعلاه ، وأدرك أن هذا الأصل يخص memo وأنه في حوزتي لتنفيذ عملي المكتبي ، وأؤكد بموجب هذا أنني سأعتني بأصول الشركة بأقصى حد ممكن وإرجاعها إلى الشركة عندما يُطلب مني ذلك.'
        : 'أقر بموجب هذا بأنني أرجعت الأصول المذكورة أعلاه لـ memo وأنها لم تعد في حوزتي.';

    final body = isH
        ? 'Please find the below as the assets handed over to you, to support you in carrying out your assignment in a most Proficient manner.'
        : 'Please find the below as the assets handed back from you to memo.';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 30),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
                child: pw.Text(isH ? 'Handover' : 'Return',
                    style: pw.TextStyle(
                        fontSize: 26, fontWeight: pw.FontWeight.bold, color: _navy))),
            pw.SizedBox(height: 2),
            pw.Center(
                child: pw.Text('memo',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 16),
            // info two columns
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    infoCell('Name of Employee', rec.employeeName),
                    infoCell('Employee Code No', rec.employeeCode),
                    infoCell('Department', rec.department),
                  ]),
                ),
                pw.Expanded(
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    infoCell('Asset Transfer Code', rec.assetTransferCode),
                    infoCell(isH ? 'Handover Date' : 'Return Date', rec.date),
                    infoCell(isH ? 'Handover By' : 'Returned To', rec.counterparty),
                  ]),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('Dear Sir / Madam We congratulate you for joining memo',
                style: pw.TextStyle(fontSize: 11, color: _navy, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(body, style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: _border, width: 0.6),
              columnWidths: {
                0: const pw.FixedColumnWidth(26),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2.4),
                3: const pw.FixedColumnWidth(30),
                4: const pw.FlexColumnWidth(2),
              },
              children: rows,
            ),
            pw.SizedBox(height: 26),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Authorized Signatory',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('Authorized Signatory',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 22),
            pw.Center(
                child: pw.Text('أقرار',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 10),
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('اقر انا : ${rec.employeeName}', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('رقم قومي : ${rec.nationalId}', style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text(declaration,
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right),
              ]),
            ),
            pw.Spacer(),
            pw.Center(
                child: pw.Text('Generated by Memo App',
                    style: const pw.TextStyle(fontSize: 8, color: _grey))),
          ],
        ),
      ),
    );
    return doc;
  }

  static String _fileName(AssetRecord rec) {
    final t = rec.type == OpType.handover ? 'Handover' : 'Return';
    final who = rec.employeeName.isEmpty ? 'employee' : rec.employeeName.replaceAll(' ', '_');
    return '${t}_${who}_${rec.date}.pdf';
  }

  /// Open the system share sheet (save to Files / send via WhatsApp / email…).
  static Future<void> share(AssetRecord rec) async {
    final doc = await _build(rec);
    await Printing.sharePdf(bytes: await doc.save(), filename: _fileName(rec));
  }

  /// Open the print / save-as-PDF preview.
  static Future<void> printOut(AssetRecord rec) async {
    final doc = await _build(rec);
    await Printing.layoutPdf(
        name: _fileName(rec), onLayout: (format) async => doc.save());
  }
}

// ===== lib/screens/scan_screen.dart =====
/// Full-screen scanner. Pops with the scanned code (String) or null.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final codes = capture.barcodes;
    if (codes.isEmpty) return;
    final value = codes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(store.tr('مسح السيريال', 'Scan Serial')),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
            tooltip: store.tr('الفلاش', 'Torch'),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
            tooltip: store.tr('تبديل الكاميرا', 'Switch camera'),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Scan frame
          Center(
            child: Container(
              width: 250,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.amber, width: 3),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 90,
            child: Column(
              children: [
                Text(
                  store.tr('وجّه الكاميرا على الباركود', 'Point the camera at the barcode'),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => _manualEntry(context),
                  icon: const Icon(Icons.keyboard, color: Colors.white),
                  label: Text(
                    store.tr('إدخال يدوي', 'Manual entry'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _manualEntry(BuildContext context) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(store.tr('اكتب السيريال', 'Enter serial')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: store.tr('SN', 'SN')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(store.tr('إلغاء', 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(store.tr('تأكيد', 'OK'))),
        ],
      ),
    );
    if (res != null && res.isNotEmpty && mounted) {
      Navigator.of(context).pop(res);
    }
  }
}

// ===== lib/screens/dashboard_screen.dart =====
class DashboardScreen extends StatelessWidget {
  final VoidCallback onNew;
  const DashboardScreen({super.key, required this.onNew});

  @override
  Widget build(BuildContext context) {
    final holdings = store.holdings();
    final holders = holdings.values.where((h) => h.total > 0).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final totalOut = holders.fold<int>(0, (s, h) => s + h.total);
    final handovers = store.records.where((r) => r.type == OpType.handover).length;
    final returns = store.records.where((r) => r.type == OpType.ret).length;

    // by type (currently in the field)
    final byType = <String, int>{};
    for (final h in holdings.values) {
      h.byType.forEach((t, q) {
        if (q > 0) byType[t] = (byType[t] ?? 0) + q;
      });
    }
    final typeList = byType.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxType = typeList.isEmpty ? 1 : typeList.first.value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        // stat grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.05,
          children: [
            StatCard(
                icon: Icons.groups,
                value: '${holders.length}',
                label: store.tr('موظفين ماسكين أجهزة', 'Employees holding assets'),
                color: AppColors.navy),
            StatCard(
                icon: Icons.inventory_2,
                value: '$totalOut',
                label: store.tr('إجمالي الأجهزة بالميدان', 'Total assets in field'),
                color: AppColors.amber),
            StatCard(
                icon: Icons.south_west,
                value: '$handovers',
                label: store.tr('عمليات تسليم', 'Handovers'),
                color: AppColors.ok),
            StatCard(
                icon: Icons.north_east,
                value: '$returns',
                label: store.tr('عمليات استلام', 'Returns'),
                color: AppColors.sub),
          ],
        ),
        const SizedBox(height: 16),

        // who holds what
        SectionCard(
          title: store.tr('مين ماسك كام جهاز', 'Who holds what'),
          subtitle: store.tr('صافي الأجهزة في حوزة كل موظف', 'Net assets per employee'),
          child: holders.isEmpty
              ? emptyState(store.tr('مفيش أجهزة مُسلّمة لحد دلوقتي', 'No assets handed out yet'))
              : Column(
                  children: holders.map((h) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppColors.soft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: AppColors.navy.withOpacity(0.12),
                            child: Text(
                              h.name.isEmpty ? '?' : h.name.substring(0, 1),
                              style: const TextStyle(
                                  color: AppColors.navy, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 14)),
                                Text(
                                    [
                                      if (h.code.isNotEmpty) '#${h.code}',
                                      if (h.dept.isNotEmpty) h.dept,
                                    ].join(' · '),
                                    style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                            decoration: BoxDecoration(
                                color: AppColors.navy,
                                borderRadius: BorderRadius.circular(9)),
                            child: Text('${h.total}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
                          ),
                          const SizedBox(width: 6),
                          Text(store.tr('جهاز', 'items'),
                              style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),

        // by type
        SectionCard(
          title: store.tr('حسب نوع الجهاز', 'By device type'),
          child: typeList.isEmpty
              ? emptyState(store.tr('لا يوجد بيانات', 'No data'))
              : Column(
                  children: typeList.map((e) {
                    final d = deviceById(e.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(d.icon, size: 16, color: AppColors.navy),
                              const SizedBox(width: 7),
                              Expanded(
                                  child: Text(store.tr(d.ar, d.en),
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600))),
                              Text('${e.value}',
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: e.value / maxType,
                              minHeight: 7,
                              backgroundColor: AppColors.line,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(AppColors.navy),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onNew,
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              padding: const EdgeInsets.symmetric(vertical: 14)),
          icon: const Icon(Icons.add),
          label: Text(store.tr('بدء عملية جديدة', 'Start new operation'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ],
    );
  }
}

// ===== lib/screens/new_operation_screen.dart =====
class _LineCtrl {
  String typeId;
  final TextEditingController model = TextEditingController();
  final TextEditingController sn = TextEditingController();
  final TextEditingController qty = TextEditingController(text: '1');
  final TextEditingController remarks = TextEditingController();
  _LineCtrl({this.typeId = 'laptop'});
  void dispose() {
    model.dispose();
    sn.dispose();
    qty.dispose();
    remarks.dispose();
  }
}

class NewOperationScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const NewOperationScreen({super.key, required this.onSaved});

  @override
  State<NewOperationScreen> createState() => _NewOperationScreenState();
}

class _NewOperationScreenState extends State<NewOperationScreen> {
  OpType _type = OpType.handover;
  bool _newEmp = true; // true = register new, false = pick existing
  Employee? _selected;

  final _name = TextEditingController();
  final _code = TextEditingController();
  final _dept = TextEditingController();
  final _nid = TextEditingController();
  final _atc = TextEditingController();
  final _counter = TextEditingController();
  DateTime _date = DateTime.now();

  final List<_LineCtrl> _lines = [_LineCtrl()];

  @override
  void initState() {
    super.initState();
    _newEmp = store.employees.isEmpty;
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _dept, _nid, _atc, _counter]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine() => setState(() => _lines.add(_LineCtrl()));
  void _removeLine(int i) {
    if (_lines.length == 1) return;
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  Future<void> _scan(int i) async {
    final res = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (res != null && res.isNotEmpty) {
      setState(() => _lines[i].sn.text = res);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.ink,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _save() {
    // resolve employee
    String name, code, dept, nid;
    if (_newEmp) {
      name = _name.text.trim();
      code = _code.text.trim();
      dept = _dept.text.trim();
      nid = _nid.text.trim();
    } else {
      if (_selected == null) {
        _toast(store.tr('اختَر الموظف الأول', 'Select an employee first'), error: true);
        return;
      }
      name = _selected!.name;
      code = _selected!.code;
      dept = _selected!.department;
      nid = _selected!.nationalId;
    }
    if (name.isEmpty) {
      _toast(store.tr('اكتب اسم الموظف', 'Enter employee name'), error: true);
      return;
    }

    final devices = <DeviceLine>[];
    for (final l in _lines) {
      final model = l.model.text.trim();
      final sn = l.sn.text.trim();
      if (model.isEmpty && sn.isEmpty) continue;
      devices.add(DeviceLine(
        typeId: l.typeId,
        model: model,
        sn: sn,
        qty: int.tryParse(l.qty.text.trim()) ?? 1,
        remarks: l.remarks.text.trim(),
      ));
    }
    if (devices.isEmpty) {
      _toast(store.tr('ضيف جهاز واحد على الأقل', 'Add at least one device'), error: true);
      return;
    }

    // register new employee
    if (_newEmp && !store.employees.any((e) => e.code == code && code.isNotEmpty)) {
      store.addEmployee(Employee(
          id: newId(), name: name, code: code, department: dept, nationalId: nid));
    }

    store.addRecord(AssetRecord(
      id: newId(),
      type: _type,
      date: DateFormat('yyyy-MM-dd').format(_date),
      assetTransferCode: _atc.text.trim(),
      counterparty: _counter.text.trim(),
      employeeName: name,
      employeeCode: code,
      department: dept,
      nationalId: nid,
      devices: devices,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));

    _toast(store.tr(
        'تم حفظ عملية ${_type == OpType.handover ? "التسليم" : "الاستلام"} ✓',
        '${_type == OpType.handover ? "Handover" : "Return"} saved ✓'));
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final isH = _type == OpType.handover;
    final accent = isH ? AppColors.navy : AppColors.amberDark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // type toggle
        Row(
          children: [
            _typeButton(OpType.handover, Icons.south_west,
                store.tr('تسليم', 'Handover'), 'Handover', AppColors.navy),
            const SizedBox(width: 10),
            _typeButton(OpType.ret, Icons.north_east,
                store.tr('استلام', 'Return'), 'Return', AppColors.amberDark),
          ],
        ),
        const SizedBox(height: 16),

        // employee
        SectionCard(
          title: store.tr('بيانات الموظف', 'Employee details'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (store.employees.isNotEmpty) ...[
                Row(
                  children: [
                    _seg(!_newEmp, Icons.groups,
                        store.tr('موظف مسجّل', 'Registered'), () => setState(() => _newEmp = false)),
                    const SizedBox(width: 8),
                    _seg(_newEmp, Icons.person_add,
                        store.tr('موظف جديد', 'New'), () => setState(() => _newEmp = true)),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              if (!_newEmp)
                DropdownButtonFormField<Employee>(
                  value: _selected,
                  isExpanded: true,
                  decoration: fieldDecoration(store.tr('اختر الموظف', 'Select employee')),
                  items: store.employees
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                                '${e.name}${e.code.isNotEmpty ? "  (#${e.code})" : ""}',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (e) => setState(() => _selected = e),
                )
              else
                Column(
                  children: [
                    Row(children: [
                      Expanded(
                          child: LabeledField(
                              label: store.tr('اسم الموظف *', 'Employee name *'),
                              controller: _name)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: LabeledField(
                              label: store.tr('الكود الوظيفي', 'Employee code'),
                              controller: _code)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: LabeledField(
                              label: store.tr('القسم', 'Department'), controller: _dept)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: LabeledField(
                              label: store.tr('الرقم القومي', 'National ID'),
                              controller: _nid,
                              keyboardType: TextInputType.number)),
                    ]),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // meta
        SectionCard(
          title: store.tr('تفاصيل العملية', 'Operation details'),
          child: Column(
            children: [
              LabeledField(label: 'Asset Transfer Code', controller: _atc),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          isH
                              ? store.tr('تاريخ التسليم', 'Handover Date')
                              : store.tr('تاريخ الاستلام', 'Return Date'),
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.sub)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.line),
                              borderRadius: BorderRadius.circular(11)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('yyyy-MM-dd').format(_date),
                                  style: const TextStyle(fontSize: 14)),
                              const Icon(Icons.calendar_today,
                                  size: 17, color: AppColors.sub),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: LabeledField(
                        label: isH
                            ? store.tr('Handover By', 'Handover By')
                            : store.tr('Returned To', 'Returned To'),
                        controller: _counter)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // devices
        SectionCard(
          title: store.tr('الأجهزة', 'Devices'),
          subtitle: store.tr('اختار النوع، واسكان السيريال أو اكتب المواصفات',
              'Pick type, scan the SN or type the specs'),
          action: TextButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add, size: 18),
            label: Text(store.tr('صف', 'Row')),
          ),
          child: Column(
            children: List.generate(_lines.length, (i) => _deviceRow(i)),
          ),
        ),
        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _save,
                style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 15)),
                icon: const Icon(Icons.check_circle),
                label: Text(store.tr('حفظ العملية', 'Save operation'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Widget _typeButton(OpType t, IconData icon, String ar, String en, Color color) {
    final on = _type == t;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _type = t),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: on ? color.withOpacity(0.10) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: on ? color : AppColors.line, width: on ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 26, color: on ? color : AppColors.sub),
              const SizedBox(height: 6),
              Text(ar,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: on ? color : AppColors.ink)),
              Text(en, style: const TextStyle(fontSize: 11, color: AppColors.sub)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seg(bool on, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.navy.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: on ? AppColors.navy : AppColors.line, width: on ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: on ? AppColors.navy : AppColors.sub),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: on ? AppColors.navy : AppColors.sub)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deviceRow(int i) {
    final l = _lines[i];
    final d = deviceById(l.typeId);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(d.icon, size: 18, color: AppColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${store.tr("جهاز", "Device")} ${i + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.navy)),
              ),
              if (_lines.length > 1)
                InkWell(
                  onTap: () => _removeLine(i),
                  child: const Icon(Icons.delete_outline,
                      size: 20, color: AppColors.danger),
                ),
            ],
          ),
          const SizedBox(height: 11),
          // type dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(store.tr('نوع الجهاز', 'Device type'),
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sub)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: l.typeId,
                isExpanded: true,
                decoration: fieldDecoration(),
                items: kDevices
                    .map((dd) => DropdownMenuItem(
                          value: dd.id,
                          child: Row(
                            children: [
                              Icon(dd.icon, size: 16, color: AppColors.sub),
                              const SizedBox(width: 8),
                              Flexible(
                                  child: Text(store.tr(dd.ar, dd.en),
                                      overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => l.typeId = v ?? 'other'),
              ),
            ],
          ),
          const SizedBox(height: 11),
          LabeledField(
              label: store.tr('الموديل (Item-Model)', 'Model (Item-Model)'),
              controller: l.model,
              hint: 'HP / Logitech…'),
          const SizedBox(height: 11),
          // SN with scan
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(store.tr('السيريال (SN)', 'Serial (SN)'),
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sub)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: l.sn,
                          decoration: fieldDecoration(
                              store.tr('اكتب أو اسكان', 'Type or scan')))),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () => _scan(i),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navyDark,
                          padding: const EdgeInsets.symmetric(horizontal: 14)),
                      child: const Icon(Icons.qr_code_scanner, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: LabeledField(
                    label: store.tr('الكمية', 'Qty'),
                    controller: l.qty,
                    keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: LabeledField(
                      label: store.tr('ملاحظات (Remarks)', 'Remarks'),
                      controller: l.remarks)),
            ],
          ),
        ],
      ),
    );
  }
}

// ===== lib/screens/records_screen.dart =====
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final _search = TextEditingController();
  String _q = '';
  String _filter = 'all'; // all | handover | ret

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AssetRecord> get _filtered {
    return store.records.where((r) {
      if (_filter == 'handover' && r.type != OpType.handover) return false;
      if (_filter == 'ret' && r.type != OpType.ret) return false;
      if (_q.isEmpty) return true;
      final s = _q.toLowerCase();
      if (r.employeeName.toLowerCase().contains(s)) return true;
      if (r.employeeCode.toLowerCase().contains(s)) return true;
      return r.devices.any((d) =>
          d.sn.toLowerCase().contains(s) || d.model.toLowerCase().contains(s));
    }).toList();
  }

  Future<void> _confirmDelete(AssetRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(store.tr('حذف العملية؟', 'Delete operation?')),
        content: Text(store.tr('مش هتقدر ترجعها تاني.', 'This cannot be undone.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(store.tr('إلغاء', 'Cancel'))),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(store.tr('حذف', 'Delete'))),
        ],
      ),
    );
    if (ok == true) store.removeRecord(r.id);
  }

  Future<void> _doPdf(AssetRecord r, bool share) async {
    try {
      if (share) {
        await PdfService.share(r);
      } else {
        await PdfService.printOut(r);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(store.tr('تعذّر إنشاء الملف', 'Could not create file')),
            backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            children: [
              TextField(
                controller: _search,
                onChanged: (v) => setState(() => _q = v),
                decoration: fieldDecoration(store.tr(
                        'ابحث بالاسم / الكود / السيريال…',
                        'Search by name / code / serial…'))
                    .copyWith(prefixIcon: const Icon(Icons.search, size: 20)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _filterChip('all', store.tr('الكل', 'All')),
                  const SizedBox(width: 8),
                  _filterChip('handover', store.tr('تسليم', 'Handover')),
                  const SizedBox(width: 8),
                  _filterChip('ret', store.tr('استلام', 'Return')),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? emptyState(store.tr('مفيش عمليات مطابقة', 'No matching operations'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _recordCard(items[i]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String id, String label) {
    final on = _filter == id;
    return InkWell(
      onTap: () => setState(() => _filter = id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: on ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? AppColors.navy : AppColors.line),
        ),
        child: Text(label,
            style: TextStyle(
                color: on ? Colors.white : AppColors.sub,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ),
    );
  }

  Widget _recordCard(AssetRecord r) {
    final isH = r.type == OpType.handover;
    final accent = isH ? AppColors.navy : AppColors.amberDark;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: const BoxDecoration(
              color: AppColors.soft,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration:
                      BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(isH ? Icons.south_west : Icons.north_east,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                          isH
                              ? store.tr('تسليم', 'Handover')
                              : store.tr('استلام', 'Return'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${r.employeeName}${r.employeeCode.isNotEmpty ? "  #${r.employeeCode}" : ""}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14.5)),
                      Text(
                          [
                            r.date,
                            if (r.department.isNotEmpty) r.department,
                            if (r.assetTransferCode.isNotEmpty) r.assetTransferCode,
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: r.devices.map((d) {
                final dt = deviceById(d.typeId);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.soft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(dt.icon, size: 15, color: AppColors.navy),
                      const SizedBox(width: 6),
                      Text(store.tr(dt.ar, dt.en),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12.5)),
                      if (d.model.isNotEmpty)
                        Text('  ·  ${d.model}',
                            style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                      if (d.sn.isNotEmpty)
                        Text('  ·  ${d.sn}',
                            style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                      if (d.qty > 1)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: AppColors.navy,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text('×${d.qty}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _doPdf(r, false),
                  icon: const Icon(Icons.print, size: 18),
                  label: Text(store.tr('طباعة', 'Print')),
                ),
                TextButton.icon(
                  onPressed: () => _doPdf(r, true),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: Text(store.tr('مشاركة PDF', 'Share PDF')),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _confirmDelete(r),
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppColors.danger),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===== lib/screens/employees_screen.dart =====
class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final holdings = store.holdings();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                    '${store.tr("الموظفين المسجّلين", "Registered employees")} (${store.employees.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              ),
              FilledButton.icon(
                onPressed: () => _addDialog(context),
                style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
                icon: const Icon(Icons.person_add, size: 18),
                label: Text(store.tr('جديد', 'New')),
              ),
            ],
          ),
        ),
        Expanded(
          child: store.employees.isEmpty
              ? emptyState(store.tr(
                  'مفيش موظفين متسجلين. ابدأ بإضافة موظف، أو هيتسجل تلقائياً مع أول عملية.',
                  'No employees yet. Add one, or they register automatically with the first operation.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: store.employees.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final e = store.employees[i];
                    final h = holdings[e.code.isNotEmpty ? e.code : e.name];
                    final held = h?.total ?? 0;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [AppColors.navy, AppColors.navyDark]),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                    e.name.isEmpty ? '?' : e.name.substring(0, 1),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800, fontSize: 15)),
                                    Text(
                                        e.code.isNotEmpty
                                            ? '#${e.code}'
                                            : store.tr('بدون كود', 'No code'),
                                        style: const TextStyle(
                                            fontSize: 12, color: AppColors.sub)),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _confirmDelete(context, e),
                                icon: const Icon(Icons.delete_outline,
                                    size: 20, color: AppColors.danger),
                              ),
                            ],
                          ),
                          const Divider(height: 18, color: AppColors.line),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  e.department.isEmpty ? '—' : e.department,
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.sub)),
                              Text(
                                  store.tr('ماسك $held جهاز', 'Holding $held items'),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: held > 0 ? AppColors.navy : AppColors.sub)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, Employee e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(store.tr('حذف الموظف؟', 'Delete employee?')),
        content: Text(e.name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(store.tr('إلغاء', 'Cancel'))),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(store.tr('حذف', 'Delete'))),
        ],
      ),
    );
    if (ok == true) store.removeEmployee(e.id);
  }

  Future<void> _addDialog(BuildContext context) async {
    final name = TextEditingController();
    final code = TextEditingController();
    final dept = TextEditingController();
    final nid = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(store.tr('تسجيل موظف جديد', 'Register new employee')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LabeledField(
                  label: store.tr('اسم الموظف *', 'Employee name *'), controller: name),
              const SizedBox(height: 10),
              LabeledField(
                  label: store.tr('الكود الوظيفي', 'Employee code'), controller: code),
              const SizedBox(height: 10),
              LabeledField(label: store.tr('القسم', 'Department'), controller: dept),
              const SizedBox(height: 10),
              LabeledField(
                  label: store.tr('الرقم القومي', 'National ID'),
                  controller: nid,
                  keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(store.tr('إلغاء', 'Cancel'))),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              if (code.text.trim().isNotEmpty &&
                  store.employees.any((x) => x.code == code.text.trim())) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(store.tr('الكود موجود قبل كده', 'Code already exists')),
                    backgroundColor: AppColors.danger));
                return;
              }
              store.addEmployee(Employee(
                id: newId(),
                name: name.text.trim(),
                code: code.text.trim(),
                department: dept.text.trim(),
                nationalId: nid.text.trim(),
              ));
              Navigator.pop(ctx);
            },
            child: Text(store.tr('حفظ', 'Save')),
          ),
        ],
      ),
    );
  }
}

// ===== lib/screens/home_shell.dart =====
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // NewOperation rebuilt fresh each time the tab is opened (key by counter)
    final pages = <Widget>[
      DashboardScreen(onNew: () => setState(() => _index = 1)),
      NewOperationScreen(onSaved: () => setState(() => _index = 2)),
      const RecordsScreen(),
      const EmployeesScreen(),
    ];

    final titles = [
      store.tr('لوحة التحكم', 'Dashboard'),
      store.tr('عملية جديدة', 'New Operation'),
      store.tr('السجلات', 'Records'),
      store.tr('الموظفين', 'Employees'),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        title: Row(
          children: [
            const MemoLogo(size: 34),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(store.tr('ميمو', 'Memo'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                Text(titles[_index],
                    style: const TextStyle(fontSize: 11, color: Color(0xFFB6C4DA))),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: OutlinedButton(
              onPressed: store.toggleLang,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0x55FFFFFF)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              child: Text(store.isAr ? 'EN' : 'ع',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 66,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: store.tr('الرئيسية', 'Home')),
          NavigationDestination(
              icon: const Icon(Icons.add_box_outlined),
              selectedIcon: const Icon(Icons.add_box),
              label: store.tr('عملية', 'New')),
          NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: store.tr('السجلات', 'Records')),
          NavigationDestination(
              icon: const Icon(Icons.people_outline),
              selectedIcon: const Icon(Icons.people),
              label: store.tr('الموظفين', 'Staff')),
        ],
      ),
    );
  }
}

// ===== lib/main.dart =====
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const MemoApp());
}

class MemoApp extends StatelessWidget {
  const MemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild whole app on language / data change.
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return MaterialApp(
          title: 'Memo',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          // Apply RTL/LTR globally (covers dialogs & sheets too).
          builder: (context, child) =>
              Directionality(textDirection: store.dir, child: child!),
          home: const HomeShell(),
        );
      },
    );
  }
}
