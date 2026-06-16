import 'dart:io';

import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeConnectionService.scan', () {
    test('maps a fake port table to ascending BridgeServers', () async {
      final service = BridgeConnectionService(
        scanner: ({required host, required minPort, required maxPort}) async => {
          19902: 'other_workspace',
          19900: 'tom_agent_container',
        },
      );

      final servers = await service.scan();

      expect(servers.map((s) => s.port), [19900, 19902]);
      expect(servers.first.workspace, 'tom_agent_container');
      expect(servers.every((s) => s.status == BridgeServerStatus.available),
          isTrue);
    });

    test('scans the full 19900–19909 range by default', () async {
      late int seenMin;
      late int seenMax;
      final service = BridgeConnectionService(
        scanner: ({required host, required minPort, required maxPort}) async {
          seenMin = minPort;
          seenMax = maxPort;
          return const {19900: 'tom_agent_container'};
        },
      );

      await service.scan();

      expect(seenMin, 19900);
      expect(seenMax, 19909);
    });
  });

  group('BridgeChoiceStore', () {
    test('round-trips the bound choice through YAML', () {
      final dir = Directory.systemTemp.createTempSync('bridge_choice_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = BridgeChoiceStore(File('${dir.path}/bridge.yaml'));

      expect(store.load(), isNull);

      store.save(const BridgeChoice(host: '127.0.0.1', port: 19900));
      final loaded = store.load();
      expect(loaded, isNotNull);
      expect(loaded!.host, '127.0.0.1');
      expect(loaded.port, 19900);

      store.clear();
      expect(store.load(), isNull);
    });
  });
}
