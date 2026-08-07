import 'package:flutter_test/flutter_test.dart';
import 'package:watm_app/features/mvp/presentation/mvp_flow_helpers.dart';

void main() {
  group('normalizeMvpRestoredStep', () {
    test('active trial always resumes at the member dashboard', () {
      for (final activityStep in [29, 30, 31, 32, 33, 34]) {
        expect(
          normalizeMvpRestoredStep(
            step: activityStep,
            hasMemberAccess: true,
            isTrial: true,
            trialDaysLeft: 6,
          ),
          28,
        );
      }
    });

    test('expired trial resumes at the renewal screen', () {
      expect(
        normalizeMvpRestoredStep(
          step: 31,
          hasMemberAccess: true,
          isTrial: true,
          trialDaysLeft: 0,
        ),
        34,
      );
    });

    test('paid member always resumes at the member dashboard', () {
      expect(
        normalizeMvpRestoredStep(
          step: 31,
          hasMemberAccess: true,
          isTrial: false,
          trialDaysLeft: 7,
        ),
        28,
      );
    });

    test('user without member access returns to the free trial offer', () {
      expect(
        normalizeMvpRestoredStep(
          step: 31,
          hasMemberAccess: false,
          isTrial: false,
          trialDaysLeft: 7,
        ),
        16,
      );
    });

    test('unfinished onboarding remains on its saved step', () {
      expect(
        normalizeMvpRestoredStep(
          step: 12,
          hasMemberAccess: false,
          isTrial: false,
          trialDaysLeft: 7,
        ),
        12,
      );
    });
  });
}
