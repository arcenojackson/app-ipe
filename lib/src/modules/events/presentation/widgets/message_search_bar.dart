import 'package:flutter/material.dart';

class MessageSearchBar extends StatelessWidget implements PreferredSizeWidget {
  const MessageSearchBar({
    super.key,
    required this.onChanged,
    this.hintText = 'Buscar mensagens...',
  });

  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withOpacity(0.7),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              Icons.clear,
              color: Colors.white.withOpacity(0.7),
            ),
            onPressed: () => onChanged(''),
          ),
        ),
      ),
      automaticallyImplyLeading: false,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
