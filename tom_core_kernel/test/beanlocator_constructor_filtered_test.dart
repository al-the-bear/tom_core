/// A constructor dependency this deployment filters out is named as such.
///
/// [SmtpMailer] exists, but only in `prod`. In `dev` the component that
/// requires it cannot be built — and "no component supplies `SmtpMailer`"
/// would be false, sending the reader to look for a declaration that is right
/// there. The graph is unsatisfiable *in this deployment*, which is its own
/// key and names the selector responsible.
///
/// Its own reflection domain, because a refused component aborts the pass.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'beanlocator_constructor_filtered_test.reflection.dart';
import 'support/bean_selection_support.dart';

@tomReflector
@TomComponent(TomNoInterface)
@prodEnvironment
class SmtpMailer {}

@tomReflector
@TomComponent(TomNoInterface)
class SignupNotifier {
  SignupNotifier(this.mailer);

  final SmtpMailer mailer;
}

void main() {
  initializeReflection();

  test('in the deployment that keeps the dependency, both are built', () {
    discoverBeansIn(prodEnvironment, platformWeb);

    expect(
      TomBean<SignupNotifier>().get().mailer,
      same(TomBean<SmtpMailer>().get()),
    );
  });

  test('in one that filters it out, the refusal names the selector', () {
    final error = locatorExceptionOf(
      () => discoverBeansIn(devEnvironment, platformWeb),
    );

    expect(
      error?.key,
      equals('beanlocator.initialization.constructor_dependency_filtered'),
    );
    expect(error?.parameters?['class'], equals('SignupNotifier'));
    expect(error?.parameters?['parameter'], equals('mailer'));
    expect(error?.parameters?['type'], equals(SmtpMailer));
    expect(error?.parameters?['selector'], equals('environment prod'));
  });
}
