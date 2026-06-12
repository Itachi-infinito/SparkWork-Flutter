import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../models/job_offer.dart';
import '../../repositories/job_offer_repository.dart';

class JobOfferListPage extends ConsumerStatefulWidget {
  const JobOfferListPage({super.key});

  @override
  ConsumerState<JobOfferListPage> createState() => _JobOfferListPageState();
}

class _JobOfferListPageState extends ConsumerState<JobOfferListPage> {
  static const _pageSize = 20;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<JobOffer> _all = [];
  List<JobOffer> _filtered = [];
  List<JobOffer> _displayed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final offers = await ref.read(jobOfferRepositoryProvider).getAllOffers();
    if (mounted) {
      setState(() {
        _all = offers;
        _filtered = offers;
        _displayed = offers.take(_pageSize).toList();
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all
          .where((o) =>
              o.title.toLowerCase().contains(q) ||
              o.companyName.toLowerCase().contains(q) ||
              o.location.toLowerCase().contains(q))
          .toList();
      _displayed = _filtered.take(_pageSize).toList();
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (_displayed.length < _filtered.length) {
        setState(() {
          final next =
              _filtered.skip(_displayed.length).take(_pageSize);
          _displayed = [..._displayed, ...next];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Offres disponibles'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/candidate/home'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher par titre, entreprise...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filter();
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (!_loading && _all.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(children: [
                Text(
                  '${_filtered.length} offre${_filtered.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ]),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: _searchCtrl.text.isNotEmpty
                            ? Icons.search_off
                            : Icons.work_off_outlined,
                        title: _searchCtrl.text.isNotEmpty
                            ? 'Aucun résultat'
                            : 'Aucune offre disponible',
                        subtitle: _searchCtrl.text.isNotEmpty
                            ? 'Essayez avec d\'autres mots-clés.'
                            : 'Les offres apparaîtront ici.',
                        action: _searchCtrl.text.isNotEmpty
                            ? OutlinedButton.icon(
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _filter();
                                },
                                icon: const Icon(Icons.clear,
                                    color: AppColors.primary, size: 16),
                                label: const Text('Effacer',
                                    style:
                                        TextStyle(color: AppColors.primary)),
                                style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: AppColors.primary)),
                              )
                            : null,
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _displayed.length +
                            (_displayed.length < _filtered.length ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _displayed.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                    color: AppColors.primary, strokeWidth: 2),
                              ),
                            );
                          }
                          return _OfferCard(offer: _displayed[i]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final JobOffer offer;
  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/candidate/offers/${offer.jobOfferId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'offer_avatar_${offer.jobOfferId}',
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryLight,
                child: Text(offer.initials,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(offer.companyName,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 2),
                    Text(offer.location,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(width: 8),
                    if (offer.contractType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(offer.contractType,
                            style: const TextStyle(
                                color: AppColors.primary, fontSize: 10)),
                      ),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}