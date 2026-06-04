import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/checkin_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Renders the appropriate metric input widget based on the active step.
class MetricInput extends ConsumerWidget {
  final int step;

  const MetricInput({
    super.key,
    required this.step,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkinProvider);
    final notifier = ref.read(checkinProvider.notifier);

    switch (step) {
      case 0:
        return _HeartRateInput(
          initialValue: state.heartRate,
          onChanged: notifier.setHeartRate,
        );
      case 1:
        return _BloodPressureInput(
          initialSystolic: state.systolic,
          initialDiastolic: state.diastolic,
          onChanged: notifier.setBloodPressure,
        );
      case 2:
        return _GlucoseInput(
          initialValue: state.glucose,
          onChanged: notifier.setGlucose,
        );
      case 3:
        return _StepsInput(
          currentSteps: state.steps ?? 8000,
          onChanged: notifier.setSteps,
        );
      case 4:
        return _SleepInput(
          currentSleep: state.sleepHours ?? 7.0,
          onChanged: notifier.setSleepHours,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── 1. Heart Rate Input (BPM) ──
class _HeartRateInput extends StatefulWidget {
  final int? initialValue;
  final ValueChanged<int?> onChanged;

  const _HeartRateInput({
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_HeartRateInput> createState() => _HeartRateInputState();
}

class _HeartRateInputState extends State<_HeartRateInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue != null ? widget.initialValue.toString() : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.number,
      onChanged: (val) {
        final parsed = int.tryParse(val);
        widget.onChanged(parsed);
      },
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textPrimary,
          ),
      decoration: InputDecoration(
        hintText: 'Enter resting rate',
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'BPM',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 2. Blood Pressure Input (Systolic & Diastolic) ──
class _BloodPressureInput extends StatefulWidget {
  final int? initialSystolic;
  final int? initialDiastolic;
  final void Function(int?, int?) onChanged;

  const _BloodPressureInput({
    required this.initialSystolic,
    required this.initialDiastolic,
    required this.onChanged,
  });

  @override
  State<_BloodPressureInput> createState() => _BloodPressureInputState();
}

class _BloodPressureInputState extends State<_BloodPressureInput> {
  late TextEditingController _sysController;
  late TextEditingController _diaController;

  @override
  void initState() {
    super.initState();
    _sysController = TextEditingController(
      text: widget.initialSystolic != null ? widget.initialSystolic.toString() : '',
    );
    _diaController = TextEditingController(
      text: widget.initialDiastolic != null ? widget.initialDiastolic.toString() : '',
    );
  }

  @override
  void dispose() {
    _sysController.dispose();
    _diaController.dispose();
    super.dispose();
  }

  void _triggerChanged() {
    final sys = int.tryParse(_sysController.text);
    final dia = int.tryParse(_diaController.text);
    widget.onChanged(sys, dia);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Systolic
        Expanded(
          child: TextFormField(
            controller: _sysController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _triggerChanged(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
            decoration: const InputDecoration(
              hintText: 'Systolic',
              labelText: 'SYS',
            ),
          ),
        ),
        
        // Slash separator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            '/',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w300,
                ),
          ),
        ),

        // Diastolic
        Expanded(
          child: TextFormField(
            controller: _diaController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _triggerChanged(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
            decoration: const InputDecoration(
              hintText: 'Diastolic',
              labelText: 'DIA',
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.md),

        // Unit indicator
        Text(
          'mmHg',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

// ── 3. Glucose Input (mg/dL) ──
class _GlucoseInput extends StatefulWidget {
  final double? initialValue;
  final ValueChanged<double?> onChanged;

  const _GlucoseInput({
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_GlucoseInput> createState() => _GlucoseInputState();
}

class _GlucoseInputState extends State<_GlucoseInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue != null ? widget.initialValue.toString() : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (val) {
        final parsed = double.tryParse(val);
        widget.onChanged(parsed);
      },
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textPrimary,
          ),
      decoration: InputDecoration(
        hintText: 'Enter level',
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'mg/dL',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 4. Steps Input (Slider) ──
class _StepsInput extends StatelessWidget {
  final int currentSteps;
  final ValueChanged<int> onChanged;

  const _StepsInput({
    required this.currentSteps,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selected:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            Text(
              '${formatter.format(currentSteps)} steps',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SliderTheme(
          data: Theme.of(context).sliderTheme,
          child: Slider(
            value: currentSteps.toDouble(),
            min: 0,
            max: 20000,
            divisions: 200,
            onChanged: (val) {
              onChanged(val.toInt());
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
            Text('10k', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
            Text('20k', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}

// ── 5. Sleep Hours Input (Slider) ──
class _SleepInput extends StatelessWidget {
  final double currentSleep;
  final ValueChanged<double> onChanged;

  const _SleepInput({
    required this.currentSleep,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selected:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            Text(
              '${currentSleep.toStringAsFixed(1)} hours',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SliderTheme(
          data: Theme.of(context).sliderTheme,
          child: Slider(
            value: currentSleep,
            min: 0.0,
            max: 12.0,
            divisions: 24, // 0.5 hour increments
            onChanged: (val) {
              onChanged(val);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0h', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
            Text('6h', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
            Text('12h', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}
