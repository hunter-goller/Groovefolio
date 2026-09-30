import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/utils/error_reporting.dart';

void main() {
  test('debug error reporting includes diagnostic details', () {
    final messages = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = previousDebugPrint);

    logAppError(
      'load collection',
      StateError('private database details'),
      StackTrace.current,
    );

    final output = messages.join('\n');
    expect(output, contains('[Groovefolio] load collection failed'));
    expect(output, contains('private database details'));
    expect(output, contains('error_reporting_test.dart'));
  });
}
