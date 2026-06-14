// Copyright (C) 2026 Chuck Talk <cwtalk1@gmail.com>
// This file is part of SysdSafe.
//
// SysdSafe is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, version 3.
//
// SysdSafe is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY. See the GNU AGPL v3 for details.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../scanner.dart';
import '../state.dart';
import 'service_detail.dart';

/// A widget that displays a list of systemd services analyzed by the scanner.
///
/// It supports dynamic filtering by service name and risk classification (e.g. UNSAFE, EXPOSED, OK).
/// Services are sorted by urgency level (exposure level descending), then alphabetically.
class ServiceListScreen extends StatefulWidget {
  final List<SystemdService> services;

  const ServiceListScreen({super.key, required this.services});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  String searchQuery = '';
  String filterLevel = 'ALL';

  /// Converts the string risk level into a numeric score for sorting purposes.
  int _urgencyValue(String level) {
    switch (level) {
      case 'UNSAFE':
        return 4;
      case 'EXPOSED':
        return 3;
      case 'MEDIUM':
        return 2;
      case 'OK':
        return 1;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    List<SystemdService> filtered = widget.services.where((s) {
      final matchesQuery = s.name.toLowerCase().contains(
        searchQuery.toLowerCase(),
      );
      final matchesLevel =
          filterLevel == 'ALL' || s.exposureLevel == filterLevel;
      return matchesQuery && matchesLevel;
    }).toList();

    filtered.sort((a, b) {
      final urgencyA = _urgencyValue(a.exposureLevel);
      final urgencyB = _urgencyValue(b.exposureLevel);
      if (urgencyA != urgencyB) {
        return urgencyB.compareTo(urgencyA); // Highest to lowest urgency
      }
      return a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ); // A to Z alphabetical
    });

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Search Services',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      searchQuery = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: filterLevel,
                items: ['ALL', 'UNSAFE', 'EXPOSED', 'MEDIUM', 'OK']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    if (val != null) filterLevel = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final service = filtered[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.security,
                      color: _getColor(service.exposureLevel),
                      size: 32,
                    ),
                    title: Text(
                      service.name,
                      style: TextStyle(
                        fontSize: appState.fontSizeBase + 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('Exposure: ${service.exposureScore}'),
                    trailing: Chip(
                      label: Text(
                        service.exposureLevel,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: appState.fontSizeBase - 2,
                        ),
                      ),
                      backgroundColor: _getColor(service.exposureLevel),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ServiceDetailScreen(service: service),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method that maps the string risk level to a themed visual color.
  Color _getColor(String level) {
    switch (level) {
      case 'UNSAFE':
        return Colors.redAccent;
      case 'EXPOSED':
        return Colors.orangeAccent;
      case 'MEDIUM':
        return Colors.yellow[700]!;
      case 'OK':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
