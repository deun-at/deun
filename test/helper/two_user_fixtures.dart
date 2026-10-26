// One group and one friendship that Ann and Bob share, as the server returns
// them, so a test can parse the same rows for either of them.

const ann = 'ann@test.com';
const bob = 'bob@test.com';

Map<String, dynamic> _memberRow(String email, String name) => {
  'group_id': 'g1',
  'email': email,
  'display_name': name,
  'username': null,
  'username_code': null,
  'is_guest': false,
  'is_favorite': false,
  'removed_at': null,
};

/// Ann paid 20 and split it evenly, so Bob owes Ann 10. Parsed for Ann the
/// group reads +10 with Bob as the counterparty; parsed for Bob, -10 with Ann.
Map<String, dynamic> sharedGroupRow({bool simplifiedExpenses = false}) => {
  'id': 'g1',
  'name': 'Trip',
  'color_value': 0xFF000000,
  'simplified_expenses': simplifiedExpenses,
  'created_at': '',
  'user_id': null,
  'currency_code': 'EUR',
  'group_member': [_memberRow(ann, 'Ann'), _memberRow(bob, 'Bob')],
  'group_shares_summary': [
    {
      'paid_by': ann,
      'paid_for': ann,
      'share_amount': 10,
      'total_expenses': 10,
      'total_share_amount': 10,
      'paid_by_display_name': 'Ann',
      'paid_for_display_name': 'Ann',
    },
    {
      'paid_by': ann,
      'paid_for': bob,
      'share_amount': 10,
      'total_expenses': 10,
      'total_share_amount': -10,
      'paid_by_display_name': 'Ann',
      'paid_for_display_name': 'Bob',
    },
  ],
};

/// The accepted friendship Ann requested and Bob accepted.
Map<String, dynamic> annBobFriendshipRow() => {
  'requester': {'email': ann, 'display_name': 'Ann'},
  'addressee': {'email': bob, 'display_name': 'Bob'},
  'status': 'accepted',
};
