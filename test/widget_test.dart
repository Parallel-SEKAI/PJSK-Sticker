import 'package:flutter_test/flutter_test.dart';
import 'package:pjsk_sticker/main.dart';

void main() {
  testWidgets('Initial UI smoke test', (WidgetTester tester) async {
    // 加载你的应用主界面
    await tester.pumpWidget(const MyApp());

    // 验证初始界面是否显示预期的标题（替换为你的实际UI文本）
    expect(find.text('PJSK Sticker'), findsOneWidget);
  });
}
