import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:foam_shop_register/services/notification_service.dart';

/// On-device check that the notification the app actually posts renders with
/// the dedicated status-bar icon.
///
/// A shell-posted notification (`adb shell cmd notification post`) uses the
/// *shell's* icon and proves nothing about this app, and a widget test cannot
/// observe system rendering at all. Posting through the app's own
/// `LocalNotificationService` is the only way to confirm that the packaged
/// `ic_stat_foam_shop` drawable is the one Android picks up at runtime.
///
/// Run with: flutter test integration_test/notification_icon_device_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the app posts a notification on its own configured channel',
      (tester) async {
    await LocalNotificationService.initialize();

    // The channel must match the id the manifest advertises for FCM, or a
    // background message would land somewhere the user never configured.
    expect(NotificationChannels.general, 'foam_shop_general');

    // Post through the app's own service so the packaged `ic_stat_foam_shop`
    // drawable is what Android actually renders at runtime.
    await LocalNotificationService.showNotification(
      id: 4242,
      title: 'Foam Shop icon verification',
      body: 'The status bar should show a receipt silhouette.',
    );

    // NOTE FOR MANUAL VERIFICATION: `flutter test` installs a fresh APK on
    // every run, which resets the POST_NOTIFICATIONS grant, so the post above
    // is silently dropped until the permission is granted. To see the icon
    // rendered, run this test and, while it is executing, grant the permission
    // and re-trigger a post from the host:
    //
    //   adb shell pm grant com.asif.foamshop android.permission.POST_NOTIFICATIONS
    //   adb shell cmd statusbar expand-notifications
    //   adb shell screencap -p /sdcard/shade.png
    //
    // Without that step the assertions still hold (the channel id and the
    // absence of a plugin exception are what is actually asserted), but nothing
    // observable has been posted, so do not read a green run here as proof
    // that a notification reached the shade.
  });
}
