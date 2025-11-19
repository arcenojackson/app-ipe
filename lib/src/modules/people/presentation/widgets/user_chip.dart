import 'package:flutter/material.dart';

import '../../../auth/models/user.dart';

class UserChip extends StatelessWidget {
  const UserChip({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
      ),
      label: Text(user.name),
    );
  }
}
