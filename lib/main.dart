import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// ================= ENTRY POINT =================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize DB before app starts
  await DatabaseHelper.instance.database;
  runApp(const WorkshopApp());
}

// ================= STATE MANAGEMENT (LOCALE) =================

// Simple State Management for Language Toggling
class LocaleNotifier extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  void toggleLocale() {
    _locale = _locale.languageCode == 'en' ? const Locale('ar') : const Locale('en');
    notifyListeners();
  }
}

final localeNotifier = LocaleNotifier();

// ================= APP ROOT =================

class WorkshopApp extends StatelessWidget {
  const WorkshopApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to locale changes
    return ListenableBuilder(
      listenable: localeNotifier,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.indigo,
            useMaterial3: true,
          ),
          // Dynamic Locale
          locale: localeNotifier.locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomePage(),
        );
      },
    );
  }
}

// ================= LOCALIZATION LOGIC =================

class AppStrings {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      'workshops': 'Workshops',
      'add_workshop': 'Add Workshop',
      'no_workshops': 'No workshops found',
      'name': 'Name',
      'address': 'Address',
      'save': 'Save',
      'syncing': 'Syncing...',
      'offline_mode': 'Offline Mode',
    },
    'ar': {
      'workshops': 'الورش',
      'add_workshop': 'إضافة ورشة',
      'no_workshops': 'لا توجد ورش',
      'name': 'الاسم',
      'address': 'العنوان',
      'save': 'حفظ',
      'syncing': 'جاري المزامنة...',
      'offline_mode': 'وضع عدم الاتصال',
    }
  };

  static String t(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return _values[locale]?[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<void> {
  const AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);
  @override
  Future<void> load(Locale locale) async {}
  @override
  bool shouldReload(_) => false;
}

// ================= MODEL =================

class Workshop {
  final String id;
  final String name;
  final String address;
  final int synced; // 0 = not synced (local only), 1 = synced

  const Workshop({
    required this.id,
    required this.name,
    required this.address,
    this.synced = 1,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'synced': synced,
  };

  factory Workshop.fromMap(Map<String, dynamic> map) => Workshop(
    id: map['id'],
    name: map['name'],
    address: map['address'],
    synced: map['synced'] ?? 1,
  );
}

// ================= DATABASE (SQLite) =================

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('workshops.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workshops (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            address TEXT NOT NULL,
            synced INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> upsertWorkshop(Workshop workshop) async {
    final db = await instance.database;
    await db.insert(
      'workshops',
      workshop.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Workshop>> getAllWorkshops() async {
    final db = await instance.database;
    final result = await db.query('workshops');
    return result.map((json) => Workshop.fromMap(json)).toList();
  }
}

// ================= REPOSITORY (SYNC LOGIC) =================

class WorkshopRepository {
  // 1. Get Local Data (Fast)
  Future<List<Workshop>> getLocalWorkshops() async {
    return await DatabaseHelper.instance.getAllWorkshops();
  }

  // 2. Fetch Remote & Sync (Slower)
  // Returns true if new data was fetched
  Future<bool> syncWithRemote() async {
    try {
      // Simulate Network Delay
      await Future.delayed(const Duration(seconds: 2));

      // Simulate Remote API Response
      final remoteData = [
        Workshop(id: '1', name: 'Al-Madina Auto', address: 'King Fahd Road'),
        Workshop(id: '2', name: 'Express Fix', address: 'Industrial Area'),
        Workshop(id: '3', name: 'Tech Cars', address: 'Olaya Street'),
      ];

      // Save to SQLite
      for (var w in remoteData) {
        await DatabaseHelper.instance.upsertWorkshop(w);
      }
      return true;
    } catch (e) {
      debugPrint("Sync Error: $e");
      return false;
    }
  }

  Future<void> addLocalWorkshop(Workshop workshop) async {
    // Save locally immediately (Optimistic UI)
    await DatabaseHelper.instance.upsertWorkshop(workshop);
    // In a real app, you would trigger a background job to POST to API here
  }
}

// ================= HOME PAGE =================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repository = WorkshopRepository();
  List<Workshop> _workshops = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // The "Offline First" Strategy
  Future<void> _loadData() async {
    // 1. Load Local DB immediately
    final localData = await _repository.getLocalWorkshops();
    if (mounted) {
      setState(() {
        _workshops = localData;
        _isLoading = false;
        _isSyncing = true; // Start showing sync indicator
      });
    }

    // 2. Background Sync
    final hasNewData = await _repository.syncWithRemote();
    
    // 3. Update UI if needed
    if (hasNewData && mounted) {
      final updatedData = await _repository.getLocalWorkshops();
      setState(() {
        _workshops = updatedData;
        _isSyncing = false;
      });
    } else if (mounted) {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'workshops')),
        actions: [
          // Language Toggle
          TextButton.icon(
            onPressed: localeNotifier.toggleLocale,
            icon: const Icon(Icons.language, color: Colors.white),
            label: Text(
              isAr ? 'English' : 'العربية',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: _isSyncing
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2.0),
                child: LinearProgressIndicator(backgroundColor: Colors.indigo.shade200),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workshops.isEmpty
              ? Center(child: Text(AppStrings.t(context, 'no_workshops')))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    itemCount: _workshops.length,
                    itemBuilder: (_, i) {
                      final w = _workshops[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.shade100,
                            child: Text(w.name[0]),
                          ),
                          title: Text(w.name),
                          subtitle: Text(w.address),
                          trailing: Icon(
                            Icons.cloud_done, 
                            size: 16, 
                            color: Colors.green.shade300
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddWorkshopPage()),
          );
          _loadData(); // Reload after return
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ================= ADD WORKSHOP =================

class AddWorkshopPage extends StatefulWidget {
  const AddWorkshopPage({super.key});

  @override
  State<AddWorkshopPage> createState() => _AddWorkshopPageState();
}

class _AddWorkshopPageState extends State<AddWorkshopPage> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _repo = WorkshopRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t(context, 'add_workshop'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: AppStrings.t(context, 'name'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _address,
              decoration: InputDecoration(
                labelText: AppStrings.t(context, 'address'),
                border: const OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (_name.text.isEmpty || _address.text.isEmpty) return;

                  await _repo.addLocalWorkshop(
                    Workshop(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _name.text,
                      address: _address.text,
                      synced: 0, // Mark as unsynced
                    ),
                  );
                  if (mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.save),
                label: Text(AppStrings.t(context, 'save')),
                style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.indigo,
                   foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
