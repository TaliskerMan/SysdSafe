import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state.dart';

class PageContainer extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final double padding;

  const PageContainer({
    super.key,
    required this.title,
    required this.children,
    this.padding = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: appState.fontSizeBase + 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}
