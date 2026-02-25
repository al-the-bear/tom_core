/// Run All Observable Examples
///
/// This file runs all the observable examples in sequence.
/// It initializes reflection once for all examples that need it.
///
/// Run: `dart run build_runner build` before executing this file.
library;

// Import the generated reflection file (run build_runner first)
import '00_run_all_examples.reflection.dart';

// Import all example files
import '01_tom_object_basics.dart' as example_01;
import '02_observer_pattern.dart' as example_02;
import '03_tom_class.dart' as example_03;
import '04_tom_list.dart' as example_04;
import '05_tom_map.dart' as example_05;
import '06_timezone_types.dart' as example_06;

void main() {
  // Initialize reflection once for all examples
  initializeReflection();

  print('╔══════════════════════════════════════════════════════════════╗');
  print('║          Running All Observable Examples                     ║');
  print('╚══════════════════════════════════════════════════════════════╝\n');

  // Run each example
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Example 1: TomObject Basics');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  example_01.run();

  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Example 2: Observer Pattern');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  example_02.run();

  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Example 3: TomClass');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  example_03.run();

  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Example 4: TomList');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  example_04.run();

  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Example 5: TomMap');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  example_05.run();

  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Example 6: Timezone Types');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  example_06.run();

  print('\n╔══════════════════════════════════════════════════════════════╗');
  print('║          All Examples Completed Successfully!                ║');
  print('╚══════════════════════════════════════════════════════════════╝');
}
