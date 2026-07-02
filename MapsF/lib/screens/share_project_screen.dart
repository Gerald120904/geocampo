import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_colors.dart';
import '../models/project_share.dart';
import '../services/service_providers.dart';
import '../widgets/app_button.dart';

class ShareProjectScreen extends ConsumerStatefulWidget {
  const ShareProjectScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.readyMapsCount,
  });

  final String projectId;
  final String? projectName;
  final int? readyMapsCount;

  @override
  ConsumerState<ShareProjectScreen> createState() => _ShareProjectScreenState();
}

class _ShareProjectScreenState extends ConsumerState<ShareProjectScreen> {
  bool loading = false;
  String? error;
  ProjectShare? share;

  String get shareLink {
    final origin = Uri.base.origin;
    return '$origin/#/share/project/${share!.token}';
  }

  String get shareMessage {
    final currentShare = share;
    if (currentShare == null) return '';
    final projectName = widget.projectName?.trim().isNotEmpty == true
        ? widget.projectName!.trim()
        : 'Proyecto';

    return '''
Te comparto un proyecto de GeoCampo.

Proyecto:
$projectName

Abrelo aqui:
$shareLink

O ingresa este codigo en GeoCampo:
${currentShare.code}
''';
  }

  Future<void> generateShare() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await ref
          .read(projectShareServiceProvider)
          .createShare(
            projectId: widget.projectId,
            expiresInDays: 7,
            maxUses: 10,
            includeObservations: false,
            includeOnlyReadyMaps: true,
          );
      if (!mounted) return;
      setState(() {
        share = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copiado correctamente.')));
  }

  Future<void> shareWithApps() async {
    if (share == null) return;

    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          title: 'Proyecto compartido de GeoCampo',
          subject: 'Proyecto compartido de GeoCampo',
          text: shareMessage,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on MissingPluginException {
      await _copyFullShareMessage(
        'No se pudo abrir el menu de compartir. Se copio el mensaje completo.',
      );
    } catch (_) {
      await _copyFullShareMessage(
        'No se pudo compartir automaticamente. Se copio el mensaje completo.',
      );
    }
  }

  Future<void> shareByWhatsApp() async {
    if (share == null) return;

    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(shareMessage)}',
    );
    await _launchShareUri(uri);
  }

  Future<void> shareByEmail() async {
    if (share == null) return;

    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': 'Proyecto compartido de GeoCampo',
        'body': shareMessage,
      },
    );
    await _launchShareUri(uri);
  }

  Future<void> _launchShareUri(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        await _copyFullShareMessage(
          'No se pudo abrir la app. Se copio el mensaje completo.',
        );
      }
    } catch (_) {
      await _copyFullShareMessage(
        'No se pudo abrir la app. Se copio el mensaje completo.',
      );
    }
  }

  Future<void> _copyFullShareMessage(String message) async {
    await Clipboard.setData(ClipboardData(text: shareMessage));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final currentShare = share;
    final projectName = widget.projectName?.trim().isNotEmpty == true
        ? widget.projectName!.trim()
        : 'Proyecto';

    return Scaffold(
      appBar: AppBar(title: const Text('Compartir proyecto')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Compartir proyecto',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      projectName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mapas listos: ${widget.readyMapsCount ?? '-'}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Modo: Importar una copia',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (error != null) ...[
              Text(error!, style: const TextStyle(color: AppColors.dangerRed)),
              const SizedBox(height: 16),
            ],
            if (currentShare == null)
              AppButton(
                label: loading ? 'Generando...' : 'Generar enlace',
                icon: Icons.ios_share_rounded,
                loading: loading,
                fullWidth: true,
                onPressed: loading ? null : generateShare,
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enlace',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        shareLink,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Copiar enlace',
                        icon: Icons.copy_rounded,
                        fullWidth: true,
                        onPressed: () => copyText(shareLink),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Compartir con apps',
                        icon: Icons.share_rounded,
                        variant: AppButtonVariant.secondary,
                        fullWidth: true,
                        onPressed: shareWithApps,
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Enviar por WhatsApp',
                        icon: Icons.chat_rounded,
                        variant: AppButtonVariant.secondary,
                        fullWidth: true,
                        onPressed: shareByWhatsApp,
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Enviar por correo / Gmail',
                        icon: Icons.email_outlined,
                        variant: AppButtonVariant.secondary,
                        fullWidth: true,
                        onPressed: shareByEmail,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Codigo',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        currentShare.code,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Copiar codigo',
                        icon: Icons.pin_rounded,
                        variant: AppButtonVariant.ghost,
                        fullWidth: true,
                        onPressed: () => copyText(currentShare.code),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
