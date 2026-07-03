import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_colors.dart';
import '../models/project.dart';
import '../models/remote_map.dart';
import '../services/service_providers.dart';
import '../widgets/app_dropdown.dart';

class UploadMapScreen extends ConsumerStatefulWidget {
  const UploadMapScreen({super.key, this.projectId});

  final String? projectId;

  @override
  ConsumerState<UploadMapScreen> createState() => _UploadMapScreenState();
}

class _UploadMapScreenState extends ConsumerState<UploadMapScreen> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  List<Project> projects = [];
  Project? selectedProject;
  PlatformFile? selectedFile;
  bool loading = true;
  bool uploading = false;
  double uploadProgress = 0;
  bool creatingProject = false;
  String? error;
  bool get selectedFileIsPdf {
    final name = selectedFile?.name.toLowerCase() ?? '';
    return name.endsWith('.pdf');
  }

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> loadProjects() async {
    try {
      final loaded = await ref.read(projectServiceProvider).listProjects();
      final matchingProjects = widget.projectId == null
          ? const <Project>[]
          : loaded.where((project) => project.id == widget.projectId).toList();
      setState(() {
        projects = loaded;
        selectedProject = widget.projectId == null
            ? (loaded.isEmpty ? null : loaded.first)
            : (matchingProjects.isEmpty ? null : matchingProjects.first);
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'tif',
        'tiff',
        'geojson',
        'gpkg',
        'mbtiles',
        'zip',
      ],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final fileName = file.name.toLowerCase();

    if (!_isSupportedMapFile(fileName)) {
      setState(() {
        selectedFile = null;
        error = 'Selecciona un archivo de mapa compatible.';
      });
      return;
    }

    setState(() {
      selectedFile = file;
      error = null;

      if (nameController.text.trim().isEmpty) {
        nameController.text = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      }
    });
  }

  Future<void> upload() async {
    final project = selectedProject;
    final file = selectedFile;
    final mapService = ref.read(mapServiceProvider);

    if (project == null) {
      setState(() => error = 'Selecciona un proyecto.');
      return;
    }

    if (file == null) {
      setState(() => error = 'Selecciona un archivo de mapa.');
      return;
    }

    if (!_isSupportedMapFile(file.name.toLowerCase())) {
      setState(() => error = 'Selecciona un archivo de mapa valido.');
      return;
    }

    if ((file.bytes == null || file.bytes!.isEmpty) && file.path == null) {
      setState(() => error = 'No se pudo leer el archivo seleccionado.');
      return;
    }

    final name = nameController.text.trim();
    if (name.length < 2) {
      setState(() => error = 'El nombre debe tener al menos 2 caracteres.');
      return;
    }

    setState(() {
      uploading = true;
      uploadProgress = 0;
      error = null;
    });

    try {
      final result = await mapService.uploadMap(
        projectId: project.id,
        name: name,
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        file: file,
        processingMode: selectedFileIsPdf ? 'quick' : 'optimized',
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() => uploadProgress = sent / total);
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ??
                'Mapa recibido correctamente. Estamos validando su ubicacion.',
          ),
        ),
      );
      if (result.status == 'duplicate_review') {
        context.go('/maps/${result.mapId}/duplicate-review');
      } else {
        final pendingMap = RemoteMap(
          id: result.mapId,
          name: name,
          status: result.status,
          sourceType: _sourceTypeLabel(file.name),
          hasPackage: false,
          rawAvailable: false,
          quickAvailable: false,
          optimizedAvailable: false,
          canOpen: false,
          canOptimize: false,
          viewMode: 'none',
          createdAt: DateTime.now(),
        );
        ref
            .read(pendingProjectMapsProvider.notifier)
            .add(project.id, pendingMap);
        context.go('/projects/${project.id}?highlight_map=${result.mapId}');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        uploading = false;
      });
    }
  }

  Future<void> createInitialProject() async {
    setState(() {
      creatingProject = true;
      error = null;
    });

    try {
      final companyService = ref.read(companyServiceProvider);
      final projectService = ref.read(projectServiceProvider);

      final companies = await companyService.listCompanies();
      final company = companies.isNotEmpty
          ? companies.first
          : await companyService.createCompany(
              name: 'GeoCampo',
              legalName: 'GeoCampo',
              identifier: 'geocampo',
            );

      final project = await projectService.createProject(
        companyId: company.id,
        name: 'Proyecto inicial',
        description: 'Proyecto creado desde Flutter para subir mapas.',
      );

      setState(() {
        projects = [project, ...projects];
        selectedProject = project;
        creatingProject = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        creatingProject = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = selectedFile?.name;

    return Scaffold(
      appBar: AppBar(title: const Text('Subir mapa')),
      body: SafeArea(
        child: loading
            ? const _UploadLoadingIndicator()
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    selectedProject == null
                        ? 'Subir mapa'
                        : 'Subir mapa a ${selectedProject!.name}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Selecciona el archivo que quieres convertir en mapa. Lo prepararemos para verlo y guardarlo sin internet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 22),
                  if (projects.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'No hay proyectos todavía',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Para subir un mapa, primero crea un proyecto. Lo dejamos listo aquí mismo.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: creatingProject
                                  ? null
                                  : createInitialProject,
                              icon: creatingProject
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.create_new_folder),
                              label: Text(
                                creatingProject
                                    ? 'Creando proyecto...'
                                    : 'Crear proyecto inicial',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (widget.projectId == null)
                    AppDropdown<Project>(
                      key: ValueKey(selectedProject?.id),
                      value: selectedProject,
                      label: 'Proyecto',
                      icon: Icons.folder_copy_outlined,
                      items: projects,
                      itemLabel: (project) => project.name,
                      enabled: !uploading,
                      onChanged: (value) =>
                          setState(() => selectedProject = value),
                    )
                  else
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Proyecto'),
                      child: Text(selectedProject?.name ?? widget.projectId!),
                    ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    enabled: !uploading,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del mapa',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descriptionController,
                    enabled: !uploading,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: uploading ? null : pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(fileName ?? 'Seleccionar archivo'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'PDF georreferenciado, GeoTIFF, GeoJSON, GeoPackage, Shapefile ZIP o MBTiles.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  FilledButton.icon(
                    onPressed: uploading ? null : upload,
                    icon: uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      uploading
                          ? 'Subiendo ${(uploadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%'
                          : selectedFileIsPdf
                          ? 'Subir y abrir PDF original'
                          : 'Subir y optimizar',
                    ),
                  ),
                  if (uploading) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: uploadProgress == 0 ? null : uploadProgress,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Estamos recibiendo tu mapa. Al terminar aparecera en el proyecto mientras se prepara en segundo plano.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _UploadLoadingIndicator extends StatelessWidget {
  const _UploadLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: AppColors.primaryGreen.withValues(alpha: .14),
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 14),
              Text(
                'Cargando proyectos',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isSupportedMapFile(String fileName) {
  return fileName.endsWith('.pdf') ||
      fileName.endsWith('.tif') ||
      fileName.endsWith('.tiff') ||
      fileName.endsWith('.geojson') ||
      fileName.endsWith('.gpkg') ||
      fileName.endsWith('.mbtiles') ||
      fileName.endsWith('.zip');
}

String _sourceTypeLabel(String fileName) {
  final lowerName = fileName.toLowerCase();
  if (lowerName.endsWith('.pdf')) return 'geopdf';
  if (lowerName.endsWith('.tif') || lowerName.endsWith('.tiff')) {
    return 'geotiff';
  }
  if (lowerName.endsWith('.geojson')) return 'geojson';
  if (lowerName.endsWith('.gpkg')) return 'geopackage';
  if (lowerName.endsWith('.mbtiles')) return 'mbtiles';
  if (lowerName.endsWith('.zip')) return 'shapefile';
  return 'mapa';
}
