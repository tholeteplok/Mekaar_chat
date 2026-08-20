import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/models/chat_request_model.dart';
import '../../../data/repositories/chat_request_repository.dart';

final incomingRequestsProvider = FutureProvider<List<ChatRequest>>((ref) async {
  final repo = ref.watch(chatRequestRepositoryProvider);
  return repo.fetchIncomingRequests();
});

/// Layar Daftar Permintaan Chat Masuk (*Chat Requests*)
class ChatRequestsScreen extends ConsumerWidget {
  const ChatRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingRequestsProvider);

    return MekaarScaffold(
      appBar: const CustomAppBar(title: 'Permintaan Chat Masuk'),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(incomingRequestsProvider),
        child: requestsAsync.when(
          data: (requests) {
            if (requests.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  MekaarStateView(
                    pose: MikaPose.ok,
                    title: 'Tidak Ada Permintaan',
                    message: 'Semua pesan masuk dari pengirim terverifikasi.',
                    illustrationSize: 100,
                    semanticLabel: 'Daftar permintaan chat kosong',
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (ctx, index) {
                final req = requests[index];
                return _RequestCard(request: req);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 80),
              MekaarStateView(
                pose: MikaPose.huft,
                title: 'Gagal Memuat Permintaan',
                message: ErrorResolver.resolve(err),
                actionLabel: 'Coba Lagi',
                onAction: () => ref.invalidate(incomingRequestsProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  final ChatRequest request;

  const _RequestCard({required this.request});

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final username = (req.senderUsername != null && req.senderUsername!.trim().isNotEmpty)
        ? req.senderUsername!
        : 'Pengguna MEKAAR';
    final note = req.invitationNote.trim().isNotEmpty
        ? req.invitationNote.trim()
        : 'Ingin terhubung dan memulai obrolan dengan Anda.';

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Pengirim
          Row(
            children: [
              Avatar(
                imageUrl: req.senderAvatarUrl,
                initial: username.isNotEmpty ? username[0].toUpperCase() : '?',
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      'Ingin terhubung via Username',
                      style: TextStyle(
                        fontSize: 11,
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Keterangan Undangan Wajib
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MekaarColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KETERANGAN UNDANGAN:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: MekaarColors.accentOf(context),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 13,
                    color: MekaarColors.textPrimaryOf(context),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3 Opsi Aksi Terpisah
          _isProcessing
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // 1. Tombol TERIMA (Hijau/Teal)
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: _handleAccept,
                        icon: const Icon(SolarIconsOutline.checkCircle, size: 18),
                        label: const Text('Terima Undangan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MekaarColors.accentOf(context),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // 2. Tombol TOLAK (Saat Ragu)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _handleReject,
                            icon: const Icon(SolarIconsOutline.closeCircle, size: 16),
                            label: const Text('Tolak'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: MekaarColors.textSecondaryOf(context),
                              side: BorderSide(color: Theme.of(context).dividerColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 3. Tombol TOLAK & BLOKIR (Saat Yakin)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _handleRejectAndBlock,
                            icon: const Icon(SolarIconsOutline.forbiddenCircle, size: 16, color: MekaarColors.sosRed),
                            label: const Text('Tolak & Blokir', style: TextStyle(color: MekaarColors.sosRed, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: MekaarColors.sosRed),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Future<void> _handleAccept() async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(chatRequestRepositoryProvider).acceptRequest(widget.request.id);
      ref.invalidate(incomingRequestsProvider);
      if (!mounted) return;
      MekaarSnackbar.success(context, 'Undangan chat disetujui!');
    } catch (e) {
      if (!mounted) return;
      MekaarSnackbar.error(
        context,
        'Gagal menyetujui: ${ErrorResolver.resolve(e)}',
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReject() async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(chatRequestRepositoryProvider).rejectRequest(widget.request.id);
      ref.invalidate(incomingRequestsProvider);
      if (!mounted) return;
      MekaarSnackbar.info(context, 'Undangan chat ditolak.');
    } catch (e) {
      if (!mounted) return;
      MekaarSnackbar.error(
        context,
        'Gagal menolak: ${ErrorResolver.resolve(e)}',
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRejectAndBlock() async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(chatRequestRepositoryProvider).rejectAndBlockRequest(
            widget.request.id,
            widget.request.senderId,
          );
      ref.invalidate(incomingRequestsProvider);
      if (!mounted) return;
      MekaarSnackbar.warning(context, 'Undangan ditolak dan pengundang telah diblokir.');
    } catch (e) {
      if (!mounted) return;
      MekaarSnackbar.error(
        context,
        'Gagal memproses: ${ErrorResolver.resolve(e)}',
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
