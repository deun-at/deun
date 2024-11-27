import '../../main.dart';
import '../expenses/expense_model.dart';

class Group {
  late int id;
  late String name;
  late int colorValue;
  late String createdAt;
  late String userId;
  late double sumAmount;
  late Map<int, Expense> expenses;

  void loadDataFromJson(Map<String, dynamic> json) {
    id = json["id"];
    name = json["name"];
    colorValue = json["color_value"];
    createdAt = json["created_at"];
    userId = json["user_id"];

    sumAmount = 0.0;
    expenses = <int, Expense>{};
    if (json["expense"] != null) {
      for (var element in json["expense"]) {
        Expense expense = Expense();
        expense.loadDataFromJson(element);
        expenses.addAll({expense.id: expense});

        sumAmount += expense.amount;
      }
    }
  }

  delete() async {
    return await supabase.from('group').delete().eq('id', id);
  }

  static Future<Map<int, Group>> fetchData() async {
    List<Map<String, dynamic>> data = await supabase
        .from('group')
        .select('*, expense(*)')
        .order('created_at', ascending: false)
        .order('created_at',
            ascending: false,
            referencedTable: 'expense'); //todo order by activity

    Map<int, Group> retData = <int, Group>{};

    for (var element in data) {
      Group group = Group();
      group.loadDataFromJson(element);
      retData.addAll({group.id: group});
    }

    return retData;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'color_value': colorValue,
      };
}
