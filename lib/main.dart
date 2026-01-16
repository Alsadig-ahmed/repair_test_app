import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';

void main() {
  runApp(const WorkshopApp());
}

class WorkshopApp extends StatelessWidget {
  const WorkshopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FixIt Workshop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
          titleLarge: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// --- Models ---

class Workshop {
  final String id;
  final String name;
  final String address;
  final String imageUrl;

  Workshop({
    required this.id,
    required this.name,
    required this.address,
    required this.imageUrl,
  });
}

class Technician {
  final String id;
  final String workshopId;
  final String name;
  final String phone;
  final String avatarUrl;

  Technician({
    required this.id,
    required this.workshopId,
    required this.name,
    required this.phone,
    required this.avatarUrl,
  });
}

// --- Mock Database Service ---

class MockDB {
  static final List<Workshop> _workshops = [
    Workshop(id: '1', name: 'Al-Madina Auto', address: 'Main St, Industrial Area', imageUrl: 'https://picsum.photos/200/300?random=1'),
    Workshop(id: '2', name: 'Elite Mechanics', address: 'Highway 10, North Sector', imageUrl: 'https://picsum.photos/200/300?random=2'),
  ];

  static final List<Technician> _technicians = [
    Technician(id: '101', workshopId: '1', name: 'Ahmed Ali', phone: '+966 501 234 567', avatarUrl: 'https://i.pravatar.cc/150?u=1'),
    Technician(id: '102', workshopId: '1', name: 'Sami Khan', phone: '+966 505 987 654', avatarUrl: 'https://i.pravatar.cc/150?u=2'),
  ];

  static Future<List<Workshop>> getWorkshops() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network
    return _workshops;
  }

  static Future<List<Technician>> getTechnicians(String workshopId) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _technicians.where((t) => t.workshopId == workshopId).toList();
  }

  static Future<void> addWorkshop(Workshop workshop) async {
    await Future.delayed(const Duration(seconds: 1));
    _workshops.add(workshop);
  }

  static Future<void> addTechnician(Technician tech) async {
    await Future.delayed(const Duration(seconds: 1));
    _technicians.add(tech);
  }
}

// --- Pages ---

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  List<Workshop> _workshops = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final data = await MockDB.getWorkshops();
    setState(() {
      _workshops = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workshops'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _workshops.isEmpty
                  ? const Center(child: Text("No workshops added yet."))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _workshops.length,
                      itemBuilder: (context, index) {
                        final workshop = _workshops[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          clipBehavior: Clip.antiAlias,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => WorkshopDetailsPage(workshop: workshop)),
                            ),
                            child: Column(
                              children: [
                                Image.network(workshop.imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover),
                                ListTile(
                                  title: Text(workshop.name, style: Theme.of(context).textTheme.titleLarge),
                                  subtitle: Text(workshop.address),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddWorkshopPage()));
          _refresh();
        },
        label: const Text('Add Workshop'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class WorkshopDetailsPage extends StatefulWidget {
  final Workshop workshop;
  const WorkshopDetailsPage({super.key, required this.workshop});

  @override
  State<WorkshopDetailsPage> createState() => _WorkshopDetailsPageState();
}

class _WorkshopDetailsPageState extends State<WorkshopDetailsPage> {
  bool _isLoading = true;
  List<Technician> _technicians = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final data = await MockDB.getTechnicians(widget.workshop.id);
    setState(() {
      _technicians = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.workshop.name)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Technicians (${_technicians.length})", style: Theme.of(context).textTheme.headlineSmall),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _technicians.length,
                    itemBuilder: (context, index) {
                      final tech = _technicians[index];
                      return ListTile(
                        leading: CircleAvatar(backgroundImage: NetworkImage(tech.avatarUrl)),
                        title: Text(tech.name),
                        subtitle: Text(tech.phone),
                        trailing: IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () {}),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => AddTechnicianPage(workshopId: widget.workshop.id)));
          _fetch();
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

class AddWorkshopPage extends StatefulWidget {
  const AddWorkshopPage({super.key});

  @override
  State<AddWorkshopPage> createState() => _AddWorkshopPageState();
}

class _AddWorkshopPageState extends State<AddWorkshopPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSaving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final newWorkshop = Workshop(
      id: DateTime.now().toString(),
      name: _nameController.text,
      address: _addressController.text,
      imageUrl: 'https://picsum.photos/200/300?random=${DateTime.now().second}',
    );

    await MockDB.addWorkshop(newWorkshop);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Workshop added successfully!")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Workshop')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Workshop Name', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Enter address' : null,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Workshop'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// AddTechnicianPage omitted for brevity but follows the same pattern as AddWorkshopPage
class AddTechnicianPage extends StatefulWidget {
  final String workshopId;
  const AddTechnicianPage({super.key, required this.workshopId});

  @override
  State<AddTechnicianPage> createState() => _AddTechnicianPageState();
}

class _AddTechnicianPageState extends State<AddTechnicianPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Technician')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : () async {
                  setState(() => _isSaving = true);
                  await MockDB.addTechnician(Technician(
                    id: DateTime.now().toString(),
                    workshopId: widget.workshopId,
                    name: _nameController.text,
                    phone: _phoneController.text,
                    avatarUrl: 'https://i.pravatar.cc/150?u=${DateTime.now().millisecond}',
                  ));
                  if(mounted) Navigator.pop(context);
                },
                child: _isSaving ? const CircularProgressIndicator() : const Text('Save Technician'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

