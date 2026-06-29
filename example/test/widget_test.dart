import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_ui_bridge_example/sections.dart';

void main() {
  testWidgets('demo sections render their titles', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              FeaturedSection(),
              MusicSection(),
              FavoritesSection(),
              RecentsSection(),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Featured'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Recently Played'), findsOneWidget);
  });
}
