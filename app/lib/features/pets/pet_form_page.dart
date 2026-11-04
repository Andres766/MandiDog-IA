import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/page_body.dart';
import '../../shared/widgets/states.dart';
import '../auth/auth_widgets.dart';

/// Crear (sin [petId]) o editar un perro.
class PetFormPage extends ConsumerWidget {
  const PetFormPage({super.key, this.petId});

  final String? petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = petId;
    if (id == null) return const _PetForm(pet: null);
    return switch (ref.watch(petProvider(id))) {
      AsyncData(:final value) => _PetForm(pet: value),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          error: error,
          onRetry: () => ref.invalidate(petProvider(id)),
        ),
      ),
      _ => Scaffold(appBar: AppBar(), body: const LoadingView()),
    };
  }
}

class _PetForm extends ConsumerStatefulWidget {
  const _PetForm({required this.pet});

  final Pet? pet;

  @override
  ConsumerState<_PetForm> createState() => _PetFormState();
}

class _PetFormState extends ConsumerState<_PetForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.pet?.name);
  late final _breed = TextEditingController(text: widget.pet?.breed);
  late final _weight = TextEditingController(
    text: widget.pet?.weightKg == null
        ? ''
        : NumberFormat.decimalPattern('es').format(widget.pet!.weightKg),
  );
  late PetSex _sex = widget.pet?.sex ?? PetSex.unknown;
  late DateTime? _birthDate = widget.pet?.birthDate;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.pet != null;

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _weight.dispose();
    super.dispose();
  }

  static double? _parseWeight(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String? _validateWeight(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    final weight = _parseWeight(value!);
    if (weight == null) return 'Escribe solo números, por ejemplo 8,5.';
    if (weight <= 0 || weight >= 120) {
      return 'El peso debe estar entre 0 y 120 kg.';
    }
    return null;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 2, now.month, now.day),
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final breed = _breed.text.trim();
    final data = <String, Object?>{
      'name': _name.text.trim(),
      'breed': breed.isEmpty ? null : breed,
      'sex': _sex.api,
      'birth_date': _birthDate == null
          ? null
          : DateFormat('yyyy-MM-dd').format(_birthDate!),
      'weight_kg': _parseWeight(_weight.text),
    };
    try {
      final api = ref.read(apiProvider);
      if (_editing) {
        final pet = await api.updatePet(widget.pet!.id, data);
        refreshPetData(ref, pet.id);
        if (mounted) context.pop();
      } else {
        final pet = await api.createPet(data);
        ref.invalidate(petsProvider);
        if (mounted) context.pushReplacement('/pets/${pet.id}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final birth = _birthDate;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar perro' : 'Agregar perro')),
      body: Form(
        key: _form,
        child: PageBody(
          children: [
            FormError(_error),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Escribe el nombre de tu perro.'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                counterText: '',
              ),
            ),
            const SizedBox(height: Spacing.md),
            TextFormField(
              controller: _breed,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Raza',
                helperText: 'Opcional. Si es criollo, escribe «Criollo».',
                counterText: '',
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text('Sexo', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: Spacing.sm),
            SegmentedButton<PetSex>(
              segments: [
                for (final sex in PetSex.values)
                  ButtonSegment(value: sex, label: Text(sex.label)),
              ],
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: Spacing.lg),
            InkWell(
              borderRadius: BorderRadius.circular(Spacing.radius),
              onTap: _pickBirthDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Fecha de nacimiento',
                  helperText: 'Opcional, aproximada si no la sabes',
                  suffixIcon: birth == null
                      ? const Icon(Icons.calendar_today_outlined)
                      : IconButton(
                          tooltip: 'Quitar fecha',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _birthDate = null),
                        ),
                ),
                child: Text(
                  birth == null
                      ? 'Elegir fecha'
                      : DateFormat("d 'de' MMMM 'de' y", 'es').format(birth),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            TextFormField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _validateWeight,
              decoration: const InputDecoration(
                labelText: 'Peso (kg)',
                helperText: 'Opcional',
                suffixText: 'kg',
              ),
            ),
            const SizedBox(height: Spacing.xl),
            BusyButton(
              label: _editing ? 'Guardar cambios' : 'Guardar',
              busy: _busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
