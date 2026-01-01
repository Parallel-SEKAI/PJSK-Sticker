import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pjsk_sticker/pages/sticker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPage extends StatefulWidget {
  const AppPage({super.key});
  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> {
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
  }

  // 检查是否是首次启动
  Future<void> _checkFirstLaunch() async {
    _prefs = await SharedPreferences.getInstance();
    final bool isFirstLaunch = _prefs.getBool('first_launch') ?? true;

    // 如果是首次启动，显示关于对话框
    if (isFirstLaunch) {
      const String about =
          "UHJvamVjdCBTZWthaSBTdGlja2VyIOS4uuWFjei0uei9r+S7tu+8jOWmguaenOaCqOaYr+S7mOi0ueiOt+W+l++8jOivt+eri+WNs+mAgOasvu+8gQpQcm9qZWN0IFNla2FpIFN0aWNrZXLvvIjku6XkuIvnroDnp7DigJzmnKzova/ku7bigJ3vvInnlKjmiLfljY/orq7nlLHmnKzova/ku7blvIDlj5HogIXvvIjku6XkuIvnroDnp7DigJzmiJHku6zigJ3vvInkuI7nlKjmiLfnrb7orqLjgILnlKjmiLflupTorqTnnJ/pmIXor7vjgIHlhYXliIbnkIbop6PmnKzljY/orq7kuK3lkITmnaHmrL7vvIzor7fnlKjmiLflrqHmhY7pmIXor7vlubbpgInmi6nmjqXlj5fmiJbkuI3mjqXlj5fmnKzljY/orq4gKOacquaIkOW5tOS6uuW6lOWcqOazleWumuebkeaKpOS6uumZquWQjOS4i+mYheivuynjgIIKICAgIOmZpOmdnuaCqOaOpeWPl+acrOWNj+iuruadoeasvu+8jOWQpuWImeaCqOaXoOadg+S4i+i9veOAgeWuieijheaIluS9v+eUqOacrOi9r+S7tuWPiuWFtuebuOWFs+acjeWKoeOAguaCqOeahOWuieijheOAgeS9v+eUqOihjOS4uuWwhuinhuS4uuWvueacrOWNj+iurueahOaOpeWPl++8jOW5tuWQjOaEj+aOpeWPl+acrOWNj+iuruWQhOmhueadoeasvueahOe6puadn+OAggoKICAgIOOAkOeUqOaIt+emgeatouihjOS4uuOAkQogICAgICAg5peg6K665Zyo5Lu75L2V5oOF5Ya15LiL77yM55So5oi36YO95LiN5b6X5L2c5Ye65pys6L2v5Lu256aB5q2i55qE6KGM5Li677yaCiAgICDvvIgx77yJ56aB5q2i5Yip55So5pys6L2v5Lu26L+b6KGM5Lu75L2V5raJ5Y+K6Imy5oOF44CB5pq05Yqb44CB56eN5peP5q2n6KeG44CB5oGQ5oCW5Li75LmJ562J5LiN6Imv5YaF5a6555qE5Lyg5pKt5ZKM5a6j5Lyg77ybCiAgICDvvIgy77yJ56aB5q2i5Ye65ZSu5pys6L2v5Lu255qE5Lu75L2V6YOo5YiG77yM5YyF5ous5L2G5LiN6ZmQ5LqO6L2v5Lu25pys5L2T77yM5rqQ5Luj56CB5Y+K5L2/55So5pa55rOV562J44CCCgogICAg44CQ5YWN6LSj5aOw5piO44CRCiAgICDvvIgx77yJ5pys6L2v5Lu25peo5Zyo5Liq5Lq65rWL6K+V5LiO5a2m5Lmg5byA5Y+R77yM6K+35Yu/55So5LqO5ZWG5Lia55So6YCU77yM6K+35Yu/55So5LqO6Z2e5rOV55So6YCU77ybCiAgICDvvIgy77yJ5oKo5b+F6aG75Zyo5LiL6L295pys6L2v5Lu25ZCO55qEMjTlsI/ml7blhoXliKDpmaTvvIzku6Xkv53miqTnm7jlupTkurrlkZjmiJbkvIHkuJrnmoTlkIjms5XmnYPnm4rvvIzlsIrph43lhbblirPliqjmiJDmnpzvvJsKICAgIO+8iDPvvInmnKzova/ku7blj6rkv53or4Hoh6rouqvkuI3kvJrljIXlkKvku7vkvZXmgbbmhI/ku6PnoIHvvIzkuI3kvJrkuLvliqjmlLbpm4bku7vkvZXkuKrkurrkv6Hmga/vvIzkvYbkuI3og73kv53or4HnrKzkuInmlrnlupPlronlhajvvJsKICAgIO+8iDTvvInmnKzova/ku7blrozlhajln7rkuo7mgqjkuKrkurrmhI/mhL/kvb/nlKjvvIzmgqjlupTor6Xlr7noh6rlt7HnmoTkvb/nlKjooYzkuLrlkozmiYDmnInnu5Pmnpzmib/mi4Xlhajpg6jotKPku7vvvJsKICAgIO+8iDXvvInmnKzova/ku7blubbkuI3kv53or4HkuI7miYDmnInmk43kvZzns7vnu5/miJbnoazku7borr7lpIflhbzlrrnjgILmiJHku6zkuI3lr7nlm6Dkvb/nlKjmnKzova/ku7bogIzkuqfnlJ/nmoTku7vkvZXmioDmnK/miJblronlhajpl67popjmib/mi4XotKPku7vvvJsKICAgIO+8iDbvvInmnKzova/ku7bkuI3kvJrmlLbpm4bjgIHlrZjlgqjjgIHkvb/nlKjku7vkvZXnlKjmiLfnmoTkuKrkurrkv6Hmga/vvIzljIXmi6zkvYbkuI3pmZDkuo7lp5PlkI3jgIHlnLDlnYDjgIHnlLXlrZDpgq7ku7blnLDlnYDjgIHnlLXor53lj7fnoIHnrYnjgILlnKjkvb/nlKjmnKzova/ku7bov4fnqIvkuK3vvIzkuI3kvJrov5vooYzku7vkvZXlvaLlvI/nmoTkuKrkurrkv6Hmga/ph4fpm4bvvJsKICAgIO+8iDfvvInnlKjmiLflm6DnrKzkuInmlrnlpoLnlLXkv6Hpg6jpl6jnmoTpgJrorq/nur/ot6/mlYXpmpzjgIHmioDmnK/pl67popjjgIHnvZHnu5zjgIHnlLXohJHmiJbmiYvmnLrmlYXpmpzjgIHlsIbns7vnu5/kuI3nqLPlrprmgKflj4rlhbbku5blkITnp43kuI3lj6/mipflipvljp/lm6DogIzpga3lj5fnmoTnu4/mtY7mjZ/lpLHvvIzmiJHku6zkuI3mib/mi4XotKPku7vjgIIKCiAgICDjgJDlhbblroPmnaHmrL7jgJEKICAgIO+8iDHvvInmiJHku6zkv53nlZnpmo/ml7bkv67mlLnjgIHlop7liqDjgIHliKDpmaTmnKzljY/orq7kuK3nmoTlhoXlrrnogIzkuI3lj6booYzpgJrnn6XnmoTmnYPliKnjgILnlKjmiLflj6/ku6XlnKjmnKzova/ku7bnmoTmnIDmlrDniYjmnKzkuK3mn6XpmIXnm7jlhbPmnaHmrL7ljY/orq7jgILmnKzljY/orq7mnaHmrL7lj5jmm7TlkI7vvIzlpoLmnpznlKjmiLfnu6fnu63kvb/nlKjmnKzova/ku7bvvIzljbPop4bkuLrnlKjmiLflt7LlkIzmhI/kv67mlLnlkI7nmoTljY/orq7jgILlpoLmnpznlKjmiLfkuI3lkIzmhI/kv67mlLnlkI7nmoTljY/orq7vvIzlupTlvZPnq4vljbPlgZzmraLkvb/nlKjmnKzova/ku7bvvJsKICAgIO+8iDLvvInmnKzljY/orq7miYDmnInnmoTmnaHmrL7moIfpopjku4XkuLrpmIXor7vmlrnkvr/vvIzmnKzouqvlubbml6Dlrp7pmYXlkKvkuYnvvIzkuI3og73kvZzkuLrmnKzljY/orq7mtrXkuYnop6Pph4rnmoTkvp3mja7vvJsKICAgIO+8iDPvvInmiJHku6zkv53nlZnlr7nkuo7mnKzljY/orq7nmoTmnIDnu4jop6Pph4rmnYPjgII=";

      Future.microtask(() {
        if (mounted) {
          showAdaptiveDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text("关于"),
                content: SingleChildScrollView(
                  padding: EdgeInsets.all(8),
                  child: Text(utf8.decode(base64Decode(about)), softWrap: true),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text("关闭"),
                  ),
                ],
              );
            },
          );
        }
      });
      // 标记为已启动过
      await _prefs.setBool('first_launch', false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkFirstLaunch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: StickerPage());
  }
}
