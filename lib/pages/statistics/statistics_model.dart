import 'package:deun/helper/helper.dart';
import 'package:jiffy/jiffy.dart';

import '../../main.dart';

class MonthlySpending {
  late String month;
  late String email;
  late String displayName;
  late double totalSpent;
  late DateTime monthDate;

  void loadDataFromJson(Map<String, dynamic> json) {
    month = json["month"];
    email = json["email"];
    displayName = json["display_name"];
    totalSpent = double.parse((json["total_spent"] ?? 0).toString());
    monthDate = DateTime.parse(month);
  }

  Map<String, dynamic> toJson() => {
        'month': month,
        'email': email,
        'display_name': displayName,
        'total_spent': totalSpent,
      };
}

class StatisticsData {
  late String groupId;
  late List<MonthlySpending> monthlySpending;
  late Map<String, List<MonthlySpending>> spendingByMember;
  late Map<String, double> totalSpendingByMember;
  late List<String> availableMonths;

  StatisticsData({required this.groupId}) {
    monthlySpending = [];
    spendingByMember = {};
    totalSpendingByMember = {};
    availableMonths = [];
  }

  void processMonthlySpendingData(List<MonthlySpending> data, {List<String>? allGroupMemberEmails, int? monthsBack}) {
    monthlySpending = data;
    spendingByMember.clear();
    totalSpendingByMember.clear();
    availableMonths.clear();

    // Group spending by member
    for (MonthlySpending spending in data) {
      if (!spendingByMember.containsKey(spending.email)) {
        spendingByMember[spending.email] = [];
        totalSpendingByMember[spending.email] = 0.0;
      }
      spendingByMember[spending.email]!.add(spending);
      totalSpendingByMember[spending.email] = (totalSpendingByMember[spending.email] ?? 0) + spending.totalSpent;
    }

    // If we have group member emails and monthsBack, fill missing data with zeros
    if (allGroupMemberEmails != null && monthsBack != null) {
      _fillMissingMonthsWithZeros(data, allGroupMemberEmails, monthsBack);
    }

    // Get unique months sorted
    Set<String> monthSet = monthlySpending.map((s) => s.month).toSet();
    availableMonths = monthSet.toList()..sort((a, b) => b.compareTo(a)); // Recent first
  }

  void _fillMissingMonthsWithZeros(
      List<MonthlySpending> originalData, List<String> allGroupMemberEmails, int monthsBack) {
    // Generate all months in the range
    Jiffy endDate = Jiffy.now().startOf(Unit.month);
    Jiffy startDate = endDate.subtract(months: monthsBack);

    List<String> allMonths = [];
    Jiffy current = startDate;
    while (current.isSameOrAfter(startDate) && current.isSameOrBefore(endDate)) {
      allMonths.add(toSQLDateStringJiffy(current));
      current = current.add(months: 1);
    }

    // Get all existing month-member combinations
    Set<String> existingCombinations = originalData.map((s) => '${s.month}_${s.email}').toSet();
    print('Existing combinations: $existingCombinations');
    // Create a map for quick lookup of display names
    Map<String, String> emailToDisplayName = {};
    for (MonthlySpending spending in originalData) {
      emailToDisplayName[spending.email] = spending.displayName;
    }

    // Add missing month-member combinations with zero spending
    List<MonthlySpending> additionalSpending = [];
    for (String month in allMonths) {
      for (String email in allGroupMemberEmails) {
        String combination = '${month}_$email';
        print('Checking combination: $combination');
        if (!existingCombinations.contains(combination)) {
          print('Adding zero spending for $combination');
          MonthlySpending zeroSpending = MonthlySpending();
          zeroSpending.month = month;
          zeroSpending.email = email;
          zeroSpending.displayName = emailToDisplayName[email] ?? email;
          zeroSpending.totalSpent = 0.0;
          zeroSpending.monthDate = DateTime.parse(month);
          additionalSpending.add(zeroSpending);
        } else {
          print('Combination already exists: $combination');
        }
      }
    }

    // Add zero entries to the main list
    monthlySpending.addAll(additionalSpending);

    // Update spendingByMember and totalSpendingByMember with zero entries
    for (MonthlySpending spending in additionalSpending) {
      if (!spendingByMember.containsKey(spending.email)) {
        spendingByMember[spending.email] = [];
        totalSpendingByMember[spending.email] = 0.0;
      }
      spendingByMember[spending.email]!.add(spending);
      // Don't add to totalSpendingByMember since it's 0
    }
  }

  List<MonthlySpending> getSpendingForMember(String email) {
    return spendingByMember[email] ?? [];
  }

  List<MonthlySpending> getSpendingForMonth(String month) {
    return monthlySpending.where((s) => s.month == month).toList();
  }

  double getTotalSpendingForMonth(String month) {
    return monthlySpending.where((s) => s.month == month).fold(0.0, (sum, s) => sum + s.totalSpent);
  }

  static Future<StatisticsData> fetchGroupStatistics(String groupId, {int monthsBack = 12}) async {
    // Calculate date range
    DateTime endDate = DateTime.now();
    DateTime startDate = DateTime(endDate.year, endDate.month - monthsBack, 1);

    // Fetch group member emails for zero-filling
    List<String> groupMemberEmails = [];
    try {
      final groupMembersData = await supabase.from('group_member').select('email').eq('group_id', groupId);

      groupMemberEmails = groupMembersData.map<String>((member) => member['email'] as String).toList();
    } catch (e) {
      print('Error fetching group members: $e');
      // Continue without group members - zero filling will still work for users with expenses
    }

    try {
      // Try using the RPC function first
      final dynamic rawData = await supabase.rpc('get_group_monthly_statistics', params: {
        'group_id_param': groupId,
        'start_date_param': startDate.toIso8601String(),
        'end_date_param': endDate.toIso8601String(),
      });

      StatisticsData statisticsData = StatisticsData(groupId: groupId);
      List<MonthlySpending> monthlySpendingList = [];

      if (rawData is List) {
        for (var element in rawData) {
          if (element is Map<String, dynamic>) {
            MonthlySpending spending = MonthlySpending();
            spending.loadDataFromJson(element);
            monthlySpendingList.add(spending);
          }
        }
      }

      // Process with zero-filling
      statisticsData.processMonthlySpendingData(
        monthlySpendingList,
        allGroupMemberEmails: groupMemberEmails.isNotEmpty ? groupMemberEmails : null,
        monthsBack: monthsBack,
      );
      return statisticsData;
    } catch (e) {
      print('Error with RPC function: $e');
      return StatisticsData(groupId: groupId);
    }
  }
}
