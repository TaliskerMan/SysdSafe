import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sysdsafe/state.dart';

class PageContainer extends StatelessWidget {
  const PageContainer({
    required this.title,
    required this.children,
    super.key,
    this.padding = 24.0,
    this.scrollable = false,
  });
  final String title;
  final List<Widget> children;
  final double padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    final content = Column(
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
    );

    if (scrollable) {
      return Scrollbar(
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          primary: true,
          padding: EdgeInsets.all(padding),
          child: content,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(padding),
      child: content,
    );
  }
}
