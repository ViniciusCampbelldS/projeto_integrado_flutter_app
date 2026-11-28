import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_integrado_flutter_app/api.dart';

void main() {
  test('entrega com ficha envia JSON e PDF para a rota administrativa', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestFuture = server.first;
    final api = PortalApi(Uri.parse('http://127.0.0.1:${server.port}/api/'));
    api.token = 'token-teste';
    final saved = api.adminSave('entregas', {'funcionarioId': 1, 'epiIds': [2], 'dataEntrega': '2026-11-27'},
        pdf: Uint8List.fromList(utf8.encode('%PDF-teste')), pdfName: 'minha ficha.pdf');
    final request = await requestFuture;
    expect(request.uri.path, '/api/admin/entregas');
    expect(request.headers.value(HttpHeaders.authorizationHeader), 'Bearer token-teste');
    expect(request.headers.contentType?.mimeType, 'multipart/form-data');
    final body = utf8.decode(await request.fold<List<int>>([], (all, chunk) => all..addAll(chunk)));
    expect(body, contains('name="entrega"'));
    expect(body, contains('filename="minha_ficha.pdf"'));
    expect(body, contains('%PDF-teste'));
    request.response.statusCode = 201;
    await request.response.close();
    await saved;
    await server.close(force: true);
  });
}
