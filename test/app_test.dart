import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_integrado_flutter_app/api.dart';
import 'package:projeto_integrado_flutter_app/main.dart';

class FakeApi extends PortalApi {
  FakeApi(this.userRole) : super(Uri.parse('http://127.0.0.1:8080/api/'));
  final String userRole;

  @override
  Future<String> login(String cpf, String senha) async {
    token = 'teste';
    role = userRole;
    return 'Pessoa de teste';
  }

  @override
  Future<List<Map<String, dynamic>>> adminList(String resource) async => [];

  @override
  Future<List<Map<String, dynamic>>> list(String path) async => [];
}

Future<void> signIn(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(MarApp(api: api));
  await tester.enterText(find.byTypeTextFieldAt(0), '12345678901');
  await tester.enterText(find.byTypeTextFieldAt(1), 'senha-teste');
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

extension on CommonFinders {
  Finder byTypeTextFieldAt(int index) => byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == 'TextFormField',
  ).at(index);
}

void main() {
  testWidgets('funcionário vê seus dados sem acesso ao catálogo de NRs', (
    tester,
  ) async {
    await signIn(tester, FakeApi('field'));
    expect(find.text('Meus EPIs'), findsOneWidget);
    expect(find.text('Meus treinamentos'), findsOneWidget);
    expect(find.text('NRs'), findsNothing);
  });

  testWidgets('administrador acessa o catálogo de NRs', (tester) async {
    await signIn(tester, FakeApi('ADM'));
    expect(find.text('Gerenciar EPIs'), findsOneWidget);
    await tester.tap(find.text('NRs'));
    await tester.pumpAndSettle();
    expect(find.text('Editar NRs'), findsOneWidget);
    expect(find.text('Adicionar'), findsOneWidget);
  });

  test('situação considera vencimento e dias de aviso', () {
    final past = DateTime.now()
        .subtract(const Duration(days: 3))
        .toIso8601String()
        .substring(0, 10);
    final soon = DateTime.now()
        .add(const Duration(days: 3))
        .toIso8601String()
        .substring(0, 10);
    expect(equipmentStatus({'vencimento': past}).$1, 'Vencido');
    expect(
      equipmentStatus({'vencimento': soon, 'diasAviso': 10}).$1,
      'Próximo do vencimento',
    );
    expect(trainingStatus({'presente': false}).$1, 'Não realizado');
    expect(
      trainingStatus({'presente': true, 'vencimento': past}).$1,
      'Vencido',
    );
  });
}
