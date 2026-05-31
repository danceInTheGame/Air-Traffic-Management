import 'package:flutter/material.dart';
import '../../../core/theme/app_colors1.dart';
import '../data/data_base_helper.dart';
import '../model/air_craft.dart';
import '../model/flight.dart';
import '../model/airport.dart';

class AviationPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 5; i++) {
      final path = Path();
      final y = size.height * (i / 5);
      path.moveTo(0, y);
      path.quadraticBezierTo(
        size.width * 0.25,
        y - 50,
        size.width * 0.5,
        y,
      );
      path.quadraticBezierTo(
        size.width * 0.75,
        y + 50,
        size.width,
        y,
      );
      canvas.drawPath(path, paint);
    }

    for (int i = 0; i < 15; i++) {
      final x = (size.width / 15) * i;
      final y = size.height * (i % 3) / 3;
      canvas.drawCircle(Offset(x, y), 3, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =====================================================
// PAGE ADMIN PRINCIPALE
// =====================================================

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseHelper _db = DatabaseHelper.instance;
  
  List<Flight> _flightHistory = [];
  List<Aircraft> _availableAircrafts = [];
  Map<String, int> _statistics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final flights = await _db.getAllFlights();
      final aircrafts = await _db.getAllAircrafts();
      final stats = await _db.getFlightStatistics();
      
      setState(() {
        _flightHistory = flights;
        _availableAircrafts = aircrafts;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: $e'),
            backgroundColor: AppColors.alert,
          ),
        );
      }
    }
  }

  // =====================================================
  // RESET DATABASE FEATURE
  // =====================================================
  Future<void> _showResetConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.alert, size: 30),
            SizedBox(width: 10),
            Text('Attention', style: TextStyle(color: AppColors.alert)),
          ],
        ),
        content: Text(
          'La base de données va être réinitialisée.\nToutes les données actuelles seront perdues et remplacées par les données par défaut.\nVoulez-vous continuer ?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alert,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Réinitialiser'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _db.resetDatabase();
        await _loadData(); // Reload data
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Base de données réinitialisée avec succès'),
              backgroundColor: AppColors.activeFlights,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la réinitialisation: $e'),
              backgroundColor: AppColors.alert,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.scaffoldBackground,
              AppColors.scaffoldBackground.withOpacity(0.9),
              const Color(0xFF1a237e),
            ],
          ),
        ),
        child: CustomPaint(
          painter: AviationPatternPainter(),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOverviewTab(),
                            _buildHistoryTab(),
                            _buildAddFlightTab(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.activeFlights,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.activeFlights.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ADMIN PANEL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Air Traffic Control Management',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.activeFlights,
            child: const Text(
              'A',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.activeFlights,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: AppColors.activeFlights.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [
          Tab(
            icon: Icon(Icons.dashboard_outlined),
            text: 'Vue d\'ensemble',
          ),
          Tab(
            icon: Icon(Icons.history),
            text: 'Historique',
          ),
          Tab(
            icon: Icon(Icons.add_circle_outline),
            text: 'Ajouter',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final inFlight = _statistics['In Flight'] ?? 0;
    final enRoute = _statistics['En Route'] ?? 0;
    final delayed = _statistics['Delayed'] ?? 0;
    final onGround = _statistics['On Ground'] ?? 0;
    final totalActive = inFlight + enRoute;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(totalActive, delayed, onGround),
          const SizedBox(height: 24),
          _buildRecentActivityCard(),
          const SizedBox(height: 24),
          _buildQuickActionsCard(),
        ],
      ),
    );
  }

  Widget _buildStatsCards(int active, int delayed, int onGround) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Vols actifs',
          '$active',
          Icons.flight_takeoff,
          AppColors.activeFlights,
        ),
        _buildStatCard(
          'Retardés',
          '$delayed',
          Icons.access_time,
          const Color(0xFFFF9800),
        ),
        _buildStatCard(
          'Au sol',
          '$onGround',
          Icons.flight_land,
          const Color(0xFF607D8B),
        ),
        _buildStatCard(
          'Avions',
          '${_availableAircrafts.length}',
          Icons.airplanemode_active,
          const Color(0xFF4CAF50),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    final recentFlights = _flightHistory.take(5).toList();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: AppColors.activeFlights),
              const SizedBox(width: 12),
              const Text(
                'Activité récente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.scaffoldBackground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (recentFlights.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Aucune activité récente',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...recentFlights.map((flight) => _buildActivityItem(flight)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Flight flight) {
    Color statusColor = _getStatusColor(flight.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      flight.flightNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        flight.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${flight.from} → ${flight.to} • ${flight.aircraft}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            flight.depTime,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Delayed':
        return const Color(0xFFFF9800);
      case 'In Flight':
      case 'En Route':
        return AppColors.activeFlights;
      case 'Boarding':
        return const Color(0xFF9C27B0);
      case 'On Ground':
        return const Color(0xFF607D8B);
      default:
        return Colors.grey;
    }
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on, color: AppColors.activeFlights),
              const SizedBox(width: 12),
              const Text(
                'Actions rapides',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.scaffoldBackground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildQuickActionButton(
                'Nouveau vol',
                Icons.add_circle,
                AppColors.activeFlights,
                () => _tabController.animateTo(2),
              ),
              _buildQuickActionButton(
                'Actualiser',
                Icons.refresh,
                const Color(0xFF607D8B),
                _loadData,
              ),
              _buildQuickActionButton(
                'Avions (${_availableAircrafts.length})',
                Icons.airplanemode_active,
                const Color(0xFF4CAF50),
                _showAircraftDialog,
              ),
              // =========== ADDED RESET BUTTON HERE =============
              _buildQuickActionButton(
                'RESET DB',
                Icons.delete_forever,
                AppColors.alert,
                _showResetConfirmationDialog,
              ),
              // =================================================
              // Moved Stats to next line/position or kept if enough space or simply replaced 
              // The original bad 'Statistiques' with empty action.
              // I'll keep 'Statistiques' but maybe 5 items make it uneven, 
              // but GridView.count with count 2 will just make another row.
              _buildQuickActionButton(
                'Statistiques',
                Icons.assessment,
                const Color(0xFF9C27B0),
                () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Historique des vols',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.scaffoldBackground,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.refresh, color: AppColors.activeFlights),
                    onPressed: _loadData,
                  ),
                  IconButton(
                    icon: Icon(Icons.filter_list, color: AppColors.activeFlights),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _flightHistory.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun vol enregistré',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: _flightHistory.length,
                    itemBuilder: (context, index) {
                      return _buildFlightHistoryCard(_flightHistory[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightHistoryCard(Flight flight) {
    Color statusColor = _getStatusColor(flight.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.activeFlights.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.flight,
                      color: AppColors.activeFlights,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        flight.flightNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        flight.aircraft,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  flight.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Départ',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      flight.from,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      flight.depTime,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: Colors.grey[400]),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Arrivée',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      flight.to,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      flight.arrTime,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddFlightTab() {
    return _AddFlightForm(
      availableAircrafts: _availableAircrafts,
      onFlightAdded: () {
        _loadData();
        _tabController.animateTo(0);
      },
      onAircraftNeeded: () => _showAircraftDialog(forSelection: true),
    );
  }

  void _showAircraftDialog({bool forSelection = false}) {
    showDialog(
      context: context,
      builder: (context) => _AircraftDialog(
        availableAircrafts: _availableAircrafts,
        onAircraftAdded: _loadData,
        forSelection: forSelection,
      ),
    );
  }
}

// =====================================================
// FORMULAIRE D'AJOUT DE VOL
// =====================================================

class _AddFlightForm extends StatefulWidget {
  final List<Aircraft> availableAircrafts;
  final VoidCallback onFlightAdded;
  final VoidCallback onAircraftNeeded;

  const _AddFlightForm({
    required this.availableAircrafts,
    required this.onFlightAdded,
    required this.onAircraftNeeded,
  });

  @override
  State<_AddFlightForm> createState() => _AddFlightFormState();
}

class _AddFlightFormState extends State<_AddFlightForm> {
  final _formKey = GlobalKey<FormState>();
  final _flightNumberController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _departureController = TextEditingController();
  final _arrivalController = TextEditingController();
  
  Aircraft? _selectedAircraft;
  String _selectedStatus = 'In Flight';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _flightNumberController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _departureController.dispose();
    _arrivalController.dispose();
    super.dispose();
  }

  Future<void> _submitFlight() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAircraft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un avion'),
          backgroundColor: AppColors.alert,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final flight = Flight(
        flightNumber: _flightNumberController.text.trim(),
        aircraft: _selectedAircraft!.registration,
        from: _fromController.text.trim().toUpperCase(),
        to: _toController.text.trim().toUpperCase(),
        status: _selectedStatus,
        depTime: _departureController.text.trim(),
        arrTime: _arrivalController.text.trim(),
      );

      await DatabaseHelper.instance.insertFlight(flight);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Vol ajouté avec succès !'),
            backgroundColor: AppColors.activeFlights,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
        
        _clearForm();
        widget.onFlightAdded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.alert,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _clearForm() {
    _flightNumberController.clear();
    _fromController.clear();
    _toController.clear();
    _departureController.clear();
    _arrivalController.clear();
    setState(() {
      _selectedAircraft = null;
      _selectedStatus = 'In Flight';
    });
  }

  @override
  Widget build(BuildContext context) {
    final groundedAircrafts = widget.availableAircrafts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.activeFlights.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.flight_takeoff,
                      color: AppColors.activeFlights,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Ajouter un nouveau vol',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.scaffoldBackground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Sélection de l'avion
              Text(
                'Sélectionner un avion',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              if (groundedAircrafts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Aucun avion disponible. Veuillez en ajouter un.',
                          style: TextStyle(color: Colors.orange[700]),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onAircraftNeeded,
                        child: const Text('Ajouter'),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Aircraft>(
                      isExpanded: true,
                      value: _selectedAircraft,
                      hint: const Text('Choisir un avion'),
                      icon: const Icon(Icons.arrow_drop_down),
                      items: groundedAircrafts.map((aircraft) {
                        return DropdownMenuItem<Aircraft>(
                          value: aircraft,
                          child: Row(
                            children: [
                              Icon(
                                Icons.airplanemode_active,
                                color: AppColors.activeFlights,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${aircraft.registration} - ${aircraft.model}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (Aircraft? value) {
                        setState(() => _selectedAircraft = value);
                      },
                    ),
                  ),
                ),
              
              if (_selectedAircraft != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.activeFlights.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.activeFlights,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Vitesse de croisière: ${_selectedAircraft!.cruiseSpeed.toInt()} km/h',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Altitude max: ${_selectedAircraft!.maxAltitude.toInt()} ft',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),

              // Numéro de vol
              TextFormField(
                controller: _flightNumberController,
                style: const TextStyle(fontSize: 15, color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Numéro de vol',
                  hintText: 'Ex: AF102',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(
                    Icons.confirmation_number,
                    color: AppColors.activeFlights,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.activeFlights,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer un numéro de vol';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),

              // Origine et Destination
              // Origine et Destination avec Autocomplete
              Row(
                children: [
                  Expanded(
                    child: _buildAirportAutocomplete(
                      controller: _fromController,
                      label: 'Origine',
                      hint: 'CDG',
                      icon: Icons.flight_takeoff,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildAirportAutocomplete(
                      controller: _toController,
                      label: 'Destination',
                      hint: 'JFK',
                      icon: Icons.flight_land,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),

              // Heures de départ et d'arrivée
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _departureController,
                      style: const TextStyle(fontSize: 15, color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Heure de départ',
                        hintText: '09:20',
                        labelStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: Icon(
                          Icons.schedule,
                          color: AppColors.activeFlights,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.activeFlights,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Requis';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _arrivalController,
                      style: const TextStyle(fontSize: 15, color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Heure d\'arrivée',
                        hintText: '12:15',
                        labelStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: Icon(
                          Icons.schedule,
                          color: AppColors.activeFlights,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.activeFlights,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Requis';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),

              // Statut
              Text(
                'Statut du vol',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  'In Flight',
                  'Delayed',
                  'On Ground',
                  'Boarding',
                ].map((status) {
                  final isSelected = _selectedStatus == status;
                  final statusColor = _getStatusColor(status);

                  return ChoiceChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedStatus = status);
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: statusColor.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? statusColor : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? statusColor : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 32),

              // Boutons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _clearForm,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Réinitialiser',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitFlight,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.activeFlights,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Ajouter le vol',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAirportAutocomplete({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<Airport>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text == '') {
              return const Iterable<Airport>.empty();
            }
            return await DatabaseHelper.instance.searchAirports(textEditingValue.text);
          },
          displayStringForOption: (Airport option) => option.oaci,
          onSelected: (Airport selection) {
            controller.text = selection.oaci;
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: 250,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Airport option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.flight, color: AppColors.activeFlights, size: 20),
                        title: Text(
                          '${option.oaci} - ${option.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${option.city}, ${option.country}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
            if (controller.text.isNotEmpty && textEditingController.text.isEmpty) {
               textEditingController.text = controller.text;
            }
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              onFieldSubmitted: (String value) {
                onFieldSubmitted();
              },
              onChanged: (value) {
                controller.text = value;
              },
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 15, color: Colors.black),
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                labelStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(
                  icon,
                  color: AppColors.activeFlights,
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.activeFlights,
                    width: 2,
                  ),
                ),
              ),
              validator: (value) {
                 if (value == null || value.trim().isEmpty) {
                  return 'Requis';
                }
                return null;
              },
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Delayed':
        return const Color(0xFFFF9800);
      case 'In Flight':
      case 'En Route':
        return AppColors.activeFlights;
      case 'Boarding':
        return const Color(0xFF9C27B0);
      case 'On Ground':
        return const Color(0xFF607D8B);
      default:
        return Colors.grey;
    }
  }
}

// =====================================================
// DIALOGUE DE GESTION DES AVIONS
// =====================================================

class _AircraftDialog extends StatefulWidget {
  final List<Aircraft> availableAircrafts;
  final VoidCallback onAircraftAdded;
  final bool forSelection;

  const _AircraftDialog({
    required this.availableAircrafts,
    required this.onAircraftAdded,
    this.forSelection = false,
  });

  @override
  State<_AircraftDialog> createState() => _AircraftDialogState();
}

class _AircraftDialogState extends State<_AircraftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _registrationController = TextEditingController();
  final _modelController = TextEditingController();
  final _cruiseSpeedController = TextEditingController();
  final _maxAltitudeController = TextEditingController();
  bool _showForm = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _registrationController.dispose();
    _modelController.dispose();
    _cruiseSpeedController.dispose();
    _maxAltitudeController.dispose();
    super.dispose();
  }

  Future<void> _addAircraft() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final aircraft = Aircraft(
        registration: _registrationController.text.trim().toUpperCase(),
        model: _modelController.text.trim(),
        cruiseSpeed: double.parse(_cruiseSpeedController.text.trim()),
        maxAltitude: double.parse(_maxAltitudeController.text.trim()),
      );

      await DatabaseHelper.instance.insertAircraft(aircraft);

      if (mounted) {
        widget.onAircraftAdded();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avion ajouté avec succès !'),
            backgroundColor: AppColors.activeFlights,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.alert,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.activeFlights.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.airplanemode_active,
                    color: AppColors.activeFlights,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Gestion des avions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            if (!_showForm) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Avions disponibles (${widget.availableAircrafts.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _showForm = true),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.activeFlights,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: widget.availableAircrafts.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun avion disponible',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.availableAircrafts.length,
                        itemBuilder: (context, index) {
                          final aircraft = widget.availableAircrafts[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.activeFlights.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.flight,
                                  color: AppColors.activeFlights,
                                ),
                              ),
                              title: Text(
                                aircraft.registration,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${aircraft.model} • ${aircraft.cruiseSpeed.toInt()} km/h',
                              ),
                              trailing: Text(
                                '${aircraft.maxAltitude.toInt()} ft',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ] else ...[
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _showForm = false),
                  ),
                  const Text(
                    'Ajouter un nouvel avion',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      TextFormField(
                        controller: _registrationController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Immatriculation',
                          hintText: 'F-GSPY',
                          prefixIcon: const Icon(Icons.tag),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _modelController,
                        decoration: InputDecoration(
                          labelText: 'Modèle',
                          hintText: 'A320',
                          prefixIcon: const Icon(Icons.airplanemode_active),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _cruiseSpeedController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Vitesse de croisière (km/h)',
                          hintText: '450',
                          prefixIcon: const Icon(Icons.speed),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Requis';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Nombre invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _maxAltitudeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Altitude maximale (ft)',
                          hintText: '39000',
                          prefixIcon: const Icon(Icons.height),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Requis';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Nombre invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _addAircraft,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.activeFlights,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Ajouter l\'avion',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
