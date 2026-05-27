import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rephoto/app.dart';

void main() {
  testWidgets('RePhoto app starts without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RePhotoApp(),
      ),
    );

    // 验证 AppBar 标题正确显示
    expect(find.text('RePhoto'), findsOneWidget);

    // 验证加载状态出现（App 启动后会请求相册权限，显示加载提示）
    expect(find.text('正在翻开您的回忆...'), findsOneWidget);
  });
}
