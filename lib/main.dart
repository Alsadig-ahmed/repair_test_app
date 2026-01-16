// PRODUCTION-READY FLUTTER APP // --------------------------------------------------------------- // Added: // - Offline caching using SharedPreferences // - Arabic & English localization (intl) // - Clean separation of concerns

import 'package:flutter/material.dart'; import 'package:shared_preferences/shared_preferences.dart'; import 'dart:convert';

void main() { runApp(const WorkshopApp()); }

// ================= LOCALIZATION =================

class L10n { final Locale locale; L10n(this.locale);

static const supportedLocales = [ Locale('en'), Locale('ar'), ];

static const _localizedValues = { 'en': { 'workshops': 'Workshops', 'add_workshop': 'Add Workshop', 'no_workshops': 'No workshops yet', 'name': 'Name', 'address': 'Address', 'save': 'Save', }, 'ar': { 'workshops': 'الورش', 'add_workshop': 'إضافة ورشة', 'no_workshops': 'لا توجد ورش', 'name': 'الاسم', 'address': 'العنوان', 'save': 'حفظ', } };

String t(String key) => _localizedValues[locale.languageCode]![key]!;

static L10n of(BuildContext context) => Localizations.of<L10n>(context, L10n)!; }

class L10nDelegate extends LocalizationsDelegate<L10n> { const L10nDelegate();

@override bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

@override Future<L10n> load(Locale locale) async => L10n(locale);

@override bool shouldReload(_) => false; }

// ================= APP ROOT =================

class WorkshopApp extends StatelessWidget { const WorkshopApp({super.key});

@override Widget build(BuildContext context) { return MaterialApp( debugShowCheckedModeBanner: false, supportedLocales: L10n.supportedLocales, localizationsDelegates: const [L10nDelegate()], locale: const Locale('en'), home: const HomePage(), ); } }

// ================= MODELS =================

@immutable class Workshop { final String id; final String name; final String address; final String imageUrl;

const Workshop({required this.id, required this.name, required this.address, required this.imageUrl});

Map<String, dynamic> toJson() => { 'id': id, 'name': name, 'address': address, 'imageUrl': imageUrl, };

factory Workshop.fromJson(Map<String, dynamic> json) => Workshop( id: json['id'], name: json['name'], address: json['address'], imageUrl: json['imageUrl'], ); }

// ================= OFFLINE CACHE =================

class WorkshopCache { static const _key = 'workshops_cache';

static Future<void> save(List<Workshop> workshops) async { final prefs = await SharedPreferences.getInstance(); final data = jsonEncode(workshops.map((w) => w.toJson()).toList()); await prefs.setString(_key, data); }

static Future<List<Workshop>> load() async { final prefs = await SharedPreferences.getInstance(); final data = prefs.getString(_key); if (data == null) return []; final list = jsonDecode(data) as List; return list.map((e) => Workshop.fromJson(e)).toList(); } }

// ================= REPOSITORY =================

class WorkshopRepository { static Future<List<Workshop>> fetchWorkshops() async { final cached = await WorkshopCache.load(); if (cached.isNotEmpty) return cached;

await Future.delayed(const Duration(milliseconds: 400));
final data = [
  Workshop(
    id: '1',
    name: 'Al-Madina Auto',
    address: 'Main Street',
    imageUrl: 'https://picsum.photos/400/200?1',
  ),
];

await WorkshopCache.save(data);
return data;

}

static Future<void> addWorkshop(Workshop workshop) async { final list = await WorkshopCache.load(); final updated = [...list, workshop]; await WorkshopCache.save(updated); } }

// ================= HOME PAGE =================

class HomePage extends StatefulWidget { const HomePage({super.key});

@override State<HomePage> createState() => _HomePageState(); }

class _HomePageState extends State<HomePage> { late Future<List<Workshop>> _future;

@override void initState() { super.initState(); _future = WorkshopRepository.fetchWorkshops(); }

@override Widget build(BuildContext context) { final t = L10n.of(context);

return Scaffold(
  appBar: AppBar(title: Text(t.t('workshops'))),
  body: FutureBuilder<List<Workshop>>(
    future: _future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final workshops = snapshot.data!;
      if (workshops.isEmpty) {
        return Center(child: Text(t.t('no_workshops')));
      }

      return ListView.builder(
        itemCount: workshops.length,
        itemBuilder: (_, i) {
          final w = workshops[i];
          return ListTile(
            title: Text(w.name),
            subtitle: Text(w.address),
          );
        },
      );
    },
  ),
  floatingActionButton: FloatingActionButton(
    onPressed: () async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWorkshopPage()));
      setState(() => _future = WorkshopRepository.fetchWorkshops());
    },
    child: const Icon(Icons.add),
  ),
);

} }

// ================= ADD WORKSHOP =================

class AddWorkshopPage extends StatefulWidget { const AddWorkshopPage({super.key});

@override State<AddWorkshopPage> createState() => _AddWorkshopPageState(); }

class _AddWorkshopPageState extends State<AddWorkshopPage> { final _name = TextEditingController(); final _address = TextEditingController();

@override Widget build(BuildContext context) { final t = L10n.of(context);

return Scaffold(
  appBar: AppBar(title: Text(t.t('add_workshop'))),
  body: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        TextField(controller: _name, decoration: InputDecoration(labelText: t.t('name'))),
        const SizedBox(height: 12),
        TextField(controller: _address, decoration: InputDecoration(labelText: t.t('address'))),
        const Spacer(),
        ElevatedButton(
          onPressed: () async {
            await WorkshopRepository.addWorkshop(
              Workshop(
                id: DateTime.now().toIso8601String(),
                name: _name.text,
                address: _address.text,
                imageUrl: '',
              ),
            );
            if (mounted) Navigator.pop(context);
          },
          child: Text(t.t('save')),
        ),
      ],
    ),
  ),
);

} }