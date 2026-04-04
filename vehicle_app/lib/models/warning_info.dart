// needed for Color usage in the model file
import 'package:flutter/material.dart';

class WarningInfo {
  final String label;
  final String displayName;
  final String description;
  final String advice;
  final String severity; // 'critical', 'warning', 'info'
  final String emoji;

  const WarningInfo({
    required this.label,
    required this.displayName,
    required this.description,
    required this.advice,
    required this.severity,
    required this.emoji,
  });
}

class WarningDatabase {
  static const Map<String, WarningInfo> warnings = {
    'abs_light': WarningInfo(
      label: 'abs_light',
      displayName: 'ABS Warning Light',
      description:
          'The Anti-lock Braking System (ABS) warning light is on. ABS prevents wheels from locking during hard braking, helping you maintain steering control.',
      advice:
          'You can still drive, but braking performance may be reduced in emergency situations. Get your ABS system inspected at a garage as soon as possible.',
      severity: 'warning',
      emoji: '🔴',
    ),
    'battery_warning': WarningInfo(
      label: 'battery_warning',
      displayName: 'Battery Warning',
      description:
          'The battery or charging system is not functioning properly. This could indicate a failing battery, alternator, or loose connection.',
      advice:
          'Do not ignore this warning. Your car may not start or could stall while driving. Visit a mechanic immediately to avoid getting stranded.',
      severity: 'critical',
      emoji: '🔋',
    ),
    'brake_pad_warning': WarningInfo(
      label: 'brake_pad_warning',
      displayName: 'Brake Pad Warning',
      description:
          'Your brake pads are worn and need replacement. Worn brake pads reduce stopping power and can damage brake discs.',
      advice:
          'Schedule a brake pad replacement as soon as possible. Continuing to drive with worn pads is dangerous and can lead to costly disc damage.',
      severity: 'critical',
      emoji: '🛑',
    ),
    'brake_system': WarningInfo(
      label: 'brake_system',
      displayName: 'Brake System Warning',
      description:
          'There is a fault in the brake system. This could mean low brake fluid, a leak, or a brake system failure.',
      advice:
          'STOP DRIVING IMMEDIATELY if accompanied by a soft brake pedal. Check brake fluid level. If unsure, call for roadside assistance — do not risk it.',
      severity: 'critical',
      emoji: '🚨',
    ),
    'bulb_failure': WarningInfo(
      label: 'bulb_failure',
      displayName: 'Bulb Failure',
      description:
          'One or more exterior lights (headlights, tail lights, or indicators) have failed. This reduces your visibility to other drivers.',
      advice:
          'Identify and replace the faulty bulb soon. In many regions, driving with a failed bulb is illegal and can result in a fine.',
      severity: 'info',
      emoji: '💡',
    ),
    'coolant': WarningInfo(
      label: 'coolant',
      displayName: 'Coolant Temperature Warning',
      description:
          'Your engine is overheating or coolant level is critically low. Overheating can cause severe and expensive engine damage.',
      advice:
          'Pull over safely and turn off the engine immediately. Do NOT open the coolant cap when hot. Let the engine cool, then check coolant level. Call a mechanic.',
      severity: 'critical',
      emoji: '🌡️',
    ),
    'engine_light': WarningInfo(
      label: 'engine_light',
      displayName: 'Check Engine Light',
      description:
          'The engine control unit has detected a fault. This can range from a loose fuel cap to a serious engine problem.',
      advice:
          'If the light is steady, get a diagnostic scan done soon. If the light is flashing, reduce speed and visit a garage immediately to prevent catalytic converter damage.',
      severity: 'warning',
      emoji: '⚙️',
    ),
    'epc_light': WarningInfo(
      label: 'epc_light',
      displayName: 'EPC Warning Light',
      description:
          'The Electronic Power Control (EPC) light indicates a fault in the throttle system, often found in Volkswagen Group vehicles.',
      advice:
          'Have the vehicle scanned with a diagnostic tool immediately. Performance may be reduced. Avoid high-speed driving until inspected by a mechanic.',
      severity: 'warning',
      emoji: '⚠️',
    ),
    'gear_box': WarningInfo(
      label: 'gear_box',
      displayName: 'Gearbox Warning',
      description:
          'A fault has been detected in the gearbox or transmission system. This may affect gear changes and driving safety.',
      advice:
          'Drive carefully to the nearest garage. Avoid aggressive acceleration. In severe cases, have the vehicle towed to prevent further transmission damage.',
      severity: 'warning',
      emoji: '⚙️',
    ),
    'power_steering_warning': WarningInfo(
      label: 'power_steering_warning',
      displayName: 'Power Steering Warning',
      description:
          'The power steering system has a fault. Steering may become much heavier and harder to control, especially at low speeds.',
      advice:
          'Drive slowly and carefully to a garage. Be prepared for significantly heavier steering. Avoid motorways until the system is repaired.',
      severity: 'warning',
      emoji: '🔧',
    ),
    'tyre_pressure': WarningInfo(
      label: 'tyre_pressure',
      displayName: 'Tyre Pressure Warning',
      description:
          'One or more tyres have low pressure. Under-inflated tyres affect handling, fuel efficiency, and can cause a blowout.',
      advice:
          'Check all tyre pressures at the nearest petrol station as soon as possible. Inflate to the recommended pressure shown in your vehicle handbook or door sill.',
      severity: 'info',
      emoji: '🛞',
    ),
  };

  static WarningInfo? getWarning(String? label) {
    if (label == null) return null;
    return warnings[label];
  }

  static Color getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
        return const Color(0xFFEF5350);
      case 'warning':
        return const Color(0xFFFFB300);
      case 'info':
        return const Color(0xFF42A5F5);
      default:
        return const Color(0xFF757575);
    }
  }
}

