import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:detail_craft/widgets/ios_swipe_to_delete.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IosSwipeToDelete Widget Tests', () {
    testWidgets('renders child content normally when closed', (tester) async {
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IosSwipeToDelete(
              onDelete: () => deleted = true,
              child: const SizedBox(
                width: 400,
                height: 80,
                child: Text('Conversation with Apex'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Conversation with Apex'), findsOneWidget);
      expect(find.byTooltip('Delete conversation'), findsOneWidget);
      expect(deleted, isFalse);
    });

    testWidgets('swiping horizontally to the left snaps open revealing delete button', (tester) async {
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 80,
                child: IosSwipeToDelete(
                  onDelete: () => deleted = true,
                  child: Container(
                    color: Colors.black,
                    width: 400,
                    height: 80,
                    child: const Text('Swipeable Row Item'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Drag left by 100 pixels
      await tester.drag(find.text('Swipeable Row Item'), const Offset(-100, 0));
      await tester.pumpAndSettle();

      final state = tester.state<IosSwipeToDeleteState>(find.byType(IosSwipeToDelete));
      expect(state.isOpen, isTrue);

      // Tap the revealed delete button
      final deleteBtn = find.byTooltip('Delete conversation');
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('small drag below threshold springs back closed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 80,
                child: IosSwipeToDelete(
                  onDelete: () {},
                  child: Container(
                    color: Colors.black,
                    width: 400,
                    height: 80,
                    child: const Text('Item to spring back'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Small drag of -15 pixels (less than half of 84px)
      await tester.drag(find.text('Item to spring back'), const Offset(-15, 0));
      await tester.pumpAndSettle();

      final state = tester.state<IosSwipeToDeleteState>(find.byType(IosSwipeToDelete));
      expect(state.isOpen, isFalse);
    });

    testWidgets('tapping on front item when open closes the swipe without child action', (tester) async {
      bool childTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 80,
                child: IosSwipeToDelete(
                  onDelete: () {},
                  child: GestureDetector(
                    onTap: () => childTapped = true,
                    child: Container(
                      color: Colors.black,
                      width: 400,
                      height: 80,
                      child: const Text('Child Tap Detector'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the swipe
      final state = tester.state<IosSwipeToDeleteState>(find.byType(IosSwipeToDelete));
      state.open();
      await tester.pumpAndSettle();
      expect(state.isOpen, isTrue);

      // Tap on the front child while open (absorbed by close-overlay)
      await tester.tap(find.text('Child Tap Detector'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Swipe should now be closed and child action did not fire
      expect(state.isOpen, isFalse);
      expect(childTapped, isFalse);
    });

    testWidgets('dragging to the right when closed does not slide past zero', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 80,
                child: IosSwipeToDelete(
                  onDelete: () {},
                  child: Container(
                    color: Colors.black,
                    width: 400,
                    height: 80,
                    child: const Text('Clamp Zero Test'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Drag right by 100 pixels
      await tester.drag(find.text('Clamp Zero Test'), const Offset(100, 0));
      await tester.pumpAndSettle();

      final state = tester.state<IosSwipeToDeleteState>(find.byType(IosSwipeToDelete));
      expect(state.isOpen, isFalse);
    });

    testWidgets('flinging to the right with positive velocity snaps open action back closed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 80,
                child: IosSwipeToDelete(
                  onDelete: () {},
                  child: Container(
                    color: Colors.black,
                    width: 400,
                    height: 80,
                    child: const Text('Fling Right Test'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final state = tester.state<IosSwipeToDeleteState>(find.byType(IosSwipeToDelete));
      state.open();
      await tester.pumpAndSettle();
      expect(state.isOpen, isTrue);

      // Fling right with high positive velocity (> 300)
      await tester.fling(find.text('Fling Right Test'), const Offset(50, 0), 1000, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(state.isOpen, isFalse);
    });

    testWidgets('rapid drag interruption during in-flight animation does not crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 80,
                child: IosSwipeToDelete(
                  onDelete: () {},
                  child: Container(
                    color: Colors.black,
                    width: 400,
                    height: 80,
                    child: const Text('Interruption Test'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final state = tester.state<IosSwipeToDeleteState>(find.byType(IosSwipeToDelete));
      state.open();
      // Pump only 50ms so animation is actively running
      await tester.pump(const Duration(milliseconds: 50));

      // Interrupt mid-animation by starting a drag
      await tester.drag(find.text('Interruption Test'), const Offset(40, 0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
