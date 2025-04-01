import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minglev2_1/Screen/auth_page.dart';

void main() {
  testWidgets('AuthPage UI elements test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AuthPage(),
        ),
      ),
    );

    // Initial state (Login form)
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byIcon(Icons.email), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(find.text("Don't have an account? Sign Up"), findsOneWidget);
    
    // Test password visibility toggle
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();
    expect(find.byIcon(Icons.visibility), findsOneWidget);

    // Switch to registration form
    await tester.tap(find.text("Don't have an account? Sign Up"));
    await tester.pumpAndSettle();

    // Registration form elements
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.byIcon(Icons.email), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.cake), findsOneWidget);
    expect(find.text('Already have an account? Sign In'), findsOneWidget);
  });

  testWidgets('Form validation test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AuthPage(),
        ),
      ),
    );

    // Try to submit empty form
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    // Verify validation messages
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    // Enter invalid email
    await tester.enterText(
      find.widgetWithIcon(TextFormField, Icons.email),
      'invalid-email'
    );
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Please enter a valid email'), findsOneWidget);

    // Enter valid email but short password
    await tester.enterText(
      find.widgetWithIcon(TextFormField, Icons.email),
      'test@example.com'
    );
    await tester.enterText(
      find.widgetWithIcon(TextFormField, Icons.lock),
      '123'
    );
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Please enter a valid email'), findsNothing);
  });

  testWidgets('Registration form validation test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AuthPage(),
        ),
      ),
    );

    // Switch to registration form
    await tester.tap(find.text("Don't have an account? Sign Up"));
    await tester.pumpAndSettle();

    // Try to submit empty form
    await tester.tap(find.text('Create Account'));
    await tester.pump();

    // Verify all required field validations
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Birthday is required'), findsOneWidget);
    expect(find.text('Please select your gender'), findsOneWidget);

    // Test password length validation
    await tester.enterText(
      find.widgetWithIcon(TextFormField, Icons.lock),
      '123'
    );
    await tester.tap(find.text('Create Account'));
    await tester.pump();

    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });

  testWidgets('Gender dropdown test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AuthPage(),
        ),
      ),
    );

    // Switch to registration form
    await tester.tap(find.text("Don't have an account? Sign Up"));
    await tester.pumpAndSettle();

    // Find and tap the gender dropdown
    expect(find.text('Select Gender'), findsOneWidget);
    await tester.tap(find.text('Select Gender'));
    await tester.pumpAndSettle();

    // Verify gender options
    expect(find.text('Male'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Non-binary'), findsOneWidget);
    expect(find.text('Transgender'), findsOneWidget);
    expect(find.text('LGBTQ+'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);

    // Select a gender
    await tester.tap(find.text('Male').last);
    await tester.pumpAndSettle();

    // Verify selection
    expect(find.text('Male'), findsOneWidget);
  });
}