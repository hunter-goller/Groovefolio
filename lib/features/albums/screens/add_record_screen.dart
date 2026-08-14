import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/widgets/ui/labeled_text_field.dart';
import 'package:vinyl_app/widgets/ui/primary_button.dart';

/// Manual record creation flow.
///
/// Discogs autofill, genre editing, artwork persistence, and NFC writing are
/// intentionally deferred so the MVP collection flow can work end-to-end.
class AddRecordScreen extends ConsumerStatefulWidget {
  const AddRecordScreen({super.key});

  @override
  ConsumerState<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends ConsumerState<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _yearController;
  late final TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _artistController = TextEditingController();
    _yearController = TextEditingController();
    _labelController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _yearController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final artist = await ref
          .read(artistRepositoryProvider)
          .findOrCreate(_artistController.text);

      final yearText = _yearController.text.trim();
      final labelText = _labelController.text.trim();

      await ref
          .read(albumMutationsProvider.notifier)
          .create(
            title: _titleController.text,
            artistId: artist.id,
            releaseYear: yearText.isEmpty ? null : int.parse(yearText),
            label: labelText.isEmpty ? null : labelText,
          );

      if (!mounted) return;
      context.go(AppRoutes.collection);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Couldn’t add record: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final mutationState = ref.watch(albumMutationsProvider);
    final isSaving = mutationState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Add a record')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              tokens.space16,
              tokens.space8,
              tokens.space16,
              tokens.space32,
            ),
            children: [
              Text(
                'Record details',
                style: context.theme.textTheme.titleLarge?.copyWith(
                  color: tokens.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: tokens.space4),
              Text(
                'Start with the basics. You can add richer metadata later.',
                style: context.theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
              SizedBox(height: tokens.space24),
              LabeledTextField(
                key: const Key('add-record-title'),
                label: 'TITLE *',
                controller: _titleController,
                hint: 'Blue Train',
                enabled: !isSaving,
                textInputAction: TextInputAction.next,
                validator: _requiredValidator('Title'),
              ),
              SizedBox(height: tokens.space16),
              LabeledTextField(
                key: const Key('add-record-artist'),
                label: 'ARTIST *',
                controller: _artistController,
                hint: 'John Coltrane',
                enabled: !isSaving,
                textInputAction: TextInputAction.next,
                validator: _requiredValidator('Artist'),
              ),
              SizedBox(height: tokens.space16),
              LabeledTextField(
                key: const Key('add-record-year'),
                label: 'YEAR',
                controller: _yearController,
                hint: '1957',
                enabled: !isSaving,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: _yearValidator,
              ),
              SizedBox(height: tokens.space16),
              LabeledTextField(
                key: const Key('add-record-label'),
                label: 'LABEL',
                controller: _labelController,
                hint: 'Blue Note',
                enabled: !isSaving,
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: tokens.space32),
              PrimaryButton(
                label: 'Add to collection',
                icon: Icons.add_rounded,
                isLoading: isSaving,
                onPressed: isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  FormFieldValidator<String> _requiredValidator(String fieldName) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldName is required';
      }
      return null;
    };
  }

  String? _yearValidator(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return null;

    final year = int.tryParse(normalized);
    if (year == null) {
      return 'Enter a valid year';
    }

    final maxYear = DateTime.now().year + 1;
    if (year < 1900 || year > maxYear) {
      return 'Enter a year from 1900 to $maxYear';
    }

    return null;
  }
}
