import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/job_offer.dart';
import '../../repositories/job_offer_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';

class RecruiterJobOffersPage extends ConsumerStatefulWidget {
  const RecruiterJobOffersPage({super.key});

  @override
  ConsumerState<RecruiterJobOffersPage> createState() =>
      _RecruiterJobOffersPageState();
}

class _RecruiterJobOffersPageState
    extends ConsumerState<RecruiterJobOffersPage> {
  List<JobOffer> _offers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = ref.read(sessionProvider);
    final offers = await ref
        .read(jobOfferRepositoryProvider)
        .getOffersByRecruiter(session.userId);
    if (mounted) setState(() { _offers = offers; _loading = false; });
  }

  Future<void> _delete(JobOffer offer) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'offre'),
        content: Text('Supprimer "${offer.title}" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(jobOfferRepositoryProvider)
          .deleteOffer(offer.jobOfferId);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mes offres'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/recruiter/offers/add');
          _load();
        },
        backgroundColor: AppColors.green,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle offre'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green))
          : _offers.isEmpty
              ? _buildEmpty()
              : _buildList(),
      bottomNavigationBar: const RecruiterNavBar(currentIndex: 2),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(
                    color: AppColors.greenLight, shape: BoxShape.circle),
                child: const Icon(Icons.work_outline,
                    color: AppColors.green, size: 40),
              ),
              const SizedBox(height: 20),
              Text('Aucune offre',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor)),
              const SizedBox(height: 8),
              Text(
                  'Publiez votre première offre pour trouver des candidats.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondaryColor)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await context.push('/recruiter/offers/add');
                  _load();
                },
                icon: const Icon(Icons.add),
                label: const Text('Créer une offre'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green),
              ),
            ],
          ),
        ),
      );

  Widget _buildList() => RefreshIndicator(
        onRefresh: _load,
        color: AppColors.green,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: _offers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final offer = _offers[i];
            return Container(
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                // IntrinsicHeight borne la hauteur du Row : sans elle,
                // stretch + ListView (hauteur non contrainte) => exception
                // "infinite height" et page blanche.
                child: IntrinsicHeight(
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF059669), AppColors.green],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(offer.title,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: context.textPrimaryColor)),
                                      const SizedBox(height: 2),
                                      Text(offer.companyName,
                                          style: TextStyle(
                                              color: context.textSecondaryColor,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'edit') {
                                      context
                                          .push(
                                              '/recruiter/offers/${offer.jobOfferId}/edit')
                                          .then((_) => _load());
                                    }
                                    if (v == 'delete') _delete(offer);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'edit',
                                        child: ListTile(
                                            leading: Icon(Icons.edit_outlined),
                                            title: Text('Modifier'),
                                            contentPadding: EdgeInsets.zero,
                                            dense: true)),
                                    PopupMenuItem(
                                        value: 'delete',
                                        child: ListTile(
                                            leading: Icon(Icons.delete_outline,
                                                color: AppColors.red),
                                            title: Text('Supprimer',
                                                style: TextStyle(
                                                    color: AppColors.red)),
                                            contentPadding: EdgeInsets.zero,
                                            dense: true)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _Tag(offer.contractType,
                                    AppColors.greenLight, AppColors.green),
                                if (offer.location.isNotEmpty)
                                  _Tag(offer.location,
                                      context.surfaceVariantColor,
                                      context.textSecondaryColor),
                                if (offer.hasSalary)
                                  _Tag(offer.salaryDisplay,
                                      AppColors.primaryLight, AppColors.primary),
                                if (offer.isFlash && offer.isFlashActive)
                                  _Tag('⚡ Flash',
                                      const Color(0xFFFFF3CD),
                                      const Color(0xFFB45309)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Tag(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      );
}
