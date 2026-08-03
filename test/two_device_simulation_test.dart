import 'package:flutter_test/flutter_test.dart';

import '../integration_test/two_device_simulation_test.dart' as simulation;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'two-device QR and Face-off simulation converges on the host',
    simulation.runTwoDeviceSimulation,
  );
}
