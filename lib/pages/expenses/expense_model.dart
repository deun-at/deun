import '../../main.dart';
import '../groups/group_model.dart';

class Expense {
  late int id;
  late Group group;
  late String name;
  late double amount;
  late String createdAt;
  late String userId;

  void loadDataFromJson(Map<String, dynamic> json) {
    id = json["id"];

    group = Group();
    if (json["group"] != null) {
      group.loadDataFromJson(json["group"]);
    }
    name = json["name"];
    amount = double.parse((json["amount"] ?? 0).toString());
    createdAt = json["created_at"];
    userId = json["user_id"];
  }

  delete() async {
    return await supabase.from('expense').delete().eq('id', id);
  }

  static Future<List<Expense>> fetchData() async {
    List<Map<String, dynamic>> data =
        await supabase.from('expense').select('*, group(*)');

    List<Expense> retData = [];

    for (var element in data) {
      Expense expense = Expense();
      expense.loadDataFromJson(element);
      retData.add(expense);
    }

    return retData;
  }
}
