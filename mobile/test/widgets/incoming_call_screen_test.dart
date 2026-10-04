import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techlink/presentation/shared/incoming_call_screen.dart';

void main() {
  Widget createWidgetUnderTest({required String callType}) {
    return MaterialApp(
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: RouteSettings(
            arguments: {
              'call_row_id': 'call123',
              'call_id': 'user123',
              'other_user_name': 'Jean Dupont',
              'call_type': callType,
            },
          ),
          builder: (context) => const IncomingCallScreen(),
        );
      },
    );
  }

  testWidgets('IncomingCallScreen affiche "Appel vidéo entrant..." si callType est video', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest(callType: 'video'));

    expect(find.text('Appel vidéo entrant...'), findsOneWidget);
    expect(find.text('Appel audio entrant...'), findsNothing);
    expect(find.text('Jean Dupont'), findsOneWidget);
    
    // Vérifier la présence des boutons accepter et refuser (icônes)
    expect(find.byIcon(Icons.call_end), findsOneWidget);
    expect(find.byIcon(Icons.call), findsOneWidget);
  });

  testWidgets('IncomingCallScreen affiche "Appel audio entrant..." si callType est audio', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest(callType: 'audio'));

    expect(find.text('Appel audio entrant...'), findsOneWidget);
    expect(find.text('Appel vidéo entrant...'), findsNothing);
    expect(find.text('Jean Dupont'), findsOneWidget);
    
    // Vérifier la présence des boutons accepter et refuser (icônes)
    expect(find.byIcon(Icons.call_end), findsOneWidget);
    expect(find.byIcon(Icons.call), findsOneWidget);
  });

  testWidgets('IncomingCallScreen affiche par défaut l\'audio si callType est inconnu', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest(callType: 'unknown_type'));

    expect(find.text('Appel audio entrant...'), findsOneWidget);
    expect(find.byIcon(Icons.call), findsOneWidget);
  });
}
