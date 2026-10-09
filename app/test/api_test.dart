import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_tutor_kazakhstan/api.dart';

void main() {
  test('Parent authentication and revision are sent only as headers', () async {
    final api = TutorApi(
      base: Uri.parse('https://example.test/v1/'),
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://example.test/v1/admin/tariff');
        expect(request.headers['Authorization'], 'Bearer adult');
        expect(request.headers['X-Parent-Pin'], '123456');
        expect(request.headers['If-Match'], '"2"');
        return http.Response('{}', 200);
      }),
    );
    api.adultToken = 'adult';
    api.pin = '123456';
    await api.request('admin/tariff', parent: true, data: {}, revision: 2);
    api.clear();
    expect(api.pin, isNull);
    expect(api.adultToken, isNull);
    api.close();
  });
}
