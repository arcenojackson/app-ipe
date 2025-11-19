import 'package:flutter/material.dart';

import '../../../auth/models/user.dart';

class PeopleSelectorSheet extends StatefulWidget {
  const PeopleSelectorSheet({
    super.key,
    required this.people,
    required this.selectedIds,
  });

  final List<UserModel> people;
  final List<String> selectedIds;

  @override
  State<PeopleSelectorSheet> createState() => _PeopleSelectorSheetState();
}

class _PeopleSelectorSheetState extends State<PeopleSelectorSheet> {
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.of(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Selecionar pessoas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400,
            child: ListView.separated(
              itemCount: widget.people.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final person = widget.people[index];
                final selected = _selectedIds.contains(person.id);
                return CheckboxListTile(
                  value: selected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedIds = [..._selectedIds, person.id];
                      } else {
                        _selectedIds = _selectedIds
                            .where((id) => id != person.id)
                            .toList();
                      }
                    });
                  },
                  title: Text(person.name),
                  subtitle: Text(person.email),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_selectedIds),
              child: const Text('Salvar'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
