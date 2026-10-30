import 'package:agrosync/core/widgets.dart';
import 'package:agrosync/domain/models.dart';
import 'package:agrosync/domain/repositories.dart';
import 'package:agrosync/features/dashboard/shell.dart';
import 'package:agrosync/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repo auth palsu: tanpa sesi, sehingga provider perangkat lain tetap kosong
/// dan tidak menyentuh repository yang belum diisi di main_*.dart.
class _FakeAuth implements AuthRepository {
  @override
  Stream<AppUser?> authState() => Stream.value(const AppUser(uid: 'u1', email: 'sari@email.com', deviceId: 'dev1'));
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signOut() async {}
}

Widget _shell({required double width}) => ProviderScope(
      overrides: [authRepoProvider.overrideWithValue(_FakeAuth())],
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: Size(width, 900)),
            child: const AppShell(location: '/beranda', child: SizedBox()),
          ),
        ),
      ),
    );

void main() {
  testWidgets('ponsel: NavigationBar bawah, tanpa NavigationRail', (tester) async {
    await tester.pumpWidget(_shell(width: 400));
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('tablet: NavigationRail, tanpa NavigationBar', (tester) async {
    await tester.pumpWidget(_shell(width: 1000));
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  test('kTablet adalah 840', () => expect(kTablet, 840.0));
}
