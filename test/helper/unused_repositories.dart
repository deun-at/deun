import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/groups/data/member_repository.dart';

/// A group repository the code under test must never call.
class UnusedGroupRepository implements GroupRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'unexpected GroupRepository.${invocation.memberName}',
  );
}

/// A member repository the code under test must never call.
class UnusedMemberRepository implements MemberRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'unexpected MemberRepository.${invocation.memberName}',
  );
}
