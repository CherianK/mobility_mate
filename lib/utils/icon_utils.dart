import 'package:flutter/material.dart';

IconData getToiletIcon(String key, dynamic value) {
  final tagKey = key.toLowerCase();
  final tagValue = value.toString().toLowerCase();

  if (tagKey == 'fee') return tagValue == 'yes' ? Icons.attach_money : Icons.money_off;
  if (tagKey == 'drinking water') {
    if (tagValue == 'yes') return Icons.water_drop;
    if (tagValue == 'no') return Icons.no_drinks;
    if (tagValue == 'seasonal') return Icons.opacity;
  }

  if (tagKey == 'access') {
    return switch (tagValue) {
      'customers' => Icons.store,
      'no' => Icons.block,
      'permissive' => Icons.check_circle_outline,
      'permit' => Icons.verified,
      'private' => Icons.lock,
      'public' => Icons.public,
      'yes' => Icons.check_circle,
      _ => Icons.info,
    };
  }

  if (tagKey == 'all gender') return tagValue == 'yes' ? Icons.group : Icons.block;
  if (tagKey == 'baby feeding' && tagValue == 'room') return Icons.child_friendly;
  if (tagKey == 'changing table') return tagValue == 'no' ? Icons.block : Icons.change_circle;
  if (tagKey == 'composting' && tagValue == 'yes') return Icons.eco;

  if (tagKey == 'disposal') {
    return switch (tagValue) {
      'chemical' => Icons.science,
      'flush' => Icons.local_drink,
      'pitlatrine' => Icons.warning,
      _ => Icons.info,
    };
  }

  if (tagKey == 'female' || tagKey == 'male' || tagKey == 'unisex') {
    return tagValue == 'yes' ? (tagKey == 'female' ? Icons.female : tagKey == 'male' ? Icons.male : Icons.transgender) : Icons.block;
  }

  if (tagKey == 'parkingaccessible') return tagValue == 'yes' ? Icons.local_parking : Icons.block;
  if (tagKey == 'portable') return tagValue == 'yes' ? Icons.wc : Icons.block;

  if (tagKey == 'position') {
    return switch (tagValue) {
      'inside' => Icons.meeting_room,
      'seated' || 'seated;urinal' => Icons.event_seat,
      'urinal' => Icons.wc,
      _ => Icons.info,
    };
  }

  if (tagKey == 'shower' && tagValue == 'yes') return Icons.shower;
  if (tagKey == 'soap' && tagValue == 'yes') return Icons.local_laundry_service;

  if (tagKey == 'wheelchair') {
    return switch (tagValue) {
      'yes' => Icons.accessible,
      'no' => Icons.block,
      'limited' => Icons.accessibility_new,
      'designated' => Icons.accessible,
      _ => Icons.info,
    };
  }

  return Icons.info;
}

IconData getTrainIcon(String key, dynamic value) {
  final tagKey = key.toLowerCase();
  final tagValue = value.toString().toLowerCase();

  if (tagKey == 'passenger_information_display') {
    return tagValue == 'yes' ? Icons.info : Icons.info_outline;
  }

  if (tagKey == 'lit') return tagValue == 'yes' ? Icons.light_mode : Icons.lightbulb_outline;
  if (tagKey == 'shelter') return tagValue == 'yes' ? Icons.house : Icons.house_siding;
  if (tagKey == 'bench') return tagValue == 'yes' ? Icons.weekend : Icons.event_busy;
  if (tagKey == 'bus' && tagValue == 'yes') return Icons.directions_bus;
  if (tagKey == 'tactile_paving') return tagValue == 'yes' ? Icons.gesture : Icons.block;

  if (tagKey == 'wheelchair') {
    return switch (tagValue) {
      'yes' => Icons.accessible,
      'no' => Icons.accessible_forward,
      'limited' => Icons.accessibility,
      _ => Icons.info,
    };
  }

  if (tagKey == 'covered' && tagValue == 'yes') return Icons.umbrella;
  if (tagKey == 'bin') return tagValue == 'yes' ? Icons.delete : Icons.delete_outline;
  if (tagKey == 'shelter_type' && tagValue == 'public_transport') return Icons.commute;
  if (tagKey == 'toilets:wheelchair' && tagValue == 'no') return Icons.wc;

  if (tagKey == 'departures_board') {
    return tagValue == 'realtime' ? Icons.update : Icons.schedule;
  }

  return Icons.info;
}

IconData getTramIcon(String key, dynamic value) {
  // Reuse train logic because tram metadata is similar
  return getTrainIcon(key, value);
}

IconData getHospitalIcon(String key, dynamic value) {
  final tagKey = key.toLowerCase();
  final tagValue = value.toString().toLowerCase();

  if (tagKey == 'healthcare') {
    return switch (tagValue) {
      'hospital' || 'clinic' => Icons.local_hospital,
      'doctor' => Icons.medical_services,
      'pharmacy' => Icons.local_pharmacy,
      'physiotherapist' => Icons.accessibility_new,
      'dentist' => Icons.medical_information,
      'alternative' => Icons.spa,
      'blood_donation' => Icons.bloodtype,
      'optometrist' => Icons.visibility,
      'psychotherapist' => Icons.psychology,
      'audiologist' => Icons.hearing,
      'laboratory' => Icons.biotech,
      'sample_collection' => Icons.science,
      _ => Icons.local_hospital,
    };
  }

  if (tagKey == 'wheelchair') {
    return switch (tagValue) {
      'yes' => Icons.accessible,
      'no' => Icons.block,
      'limited' => Icons.accessible_forward,
      'designated' => Icons.accessibility,
      _ => Icons.info,
    };
  }

  if (tagKey == 'amenity') {
    return switch (tagValue) {
      'clinic' => Icons.local_hospital,
      'pharmacy' => Icons.local_pharmacy,
      'doctors' => Icons.medical_services,
      'dentist' => Icons.medical_information,
      'hospital' => Icons.local_hospital,
      _ => Icons.info,
    };
  }

  if (tagKey == 'opening_hours') return Icons.access_time;
  if (tagKey == 'phone') return Icons.phone;
  if (tagKey == 'website') return Icons.language;
  if (tagKey == 'name') return Icons.label;
  if (tagKey == 'brand') return Icons.store;
  if (tagKey == 'operator') return Icons.account_circle;

  return Icons.info;
}
