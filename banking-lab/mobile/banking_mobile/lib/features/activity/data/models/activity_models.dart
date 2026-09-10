import 'package:banking_mobile/core/identifiers/secure_uuid_v4.dart';

enum ActivityType { developmentFunding, internalTransfer }

enum ActivityDirection { incoming, outgoing }

enum ActivityCounterpartyType { kk10pAccount, simulatorIssuer }

class ActivityFilters {
  const ActivityFilters({this.direction, this.type});

  final ActivityDirection? direction;
  final ActivityType? type;

  bool get isEmpty => direction == null && type == null;
}

class ActivityItem {
  const ActivityItem({
    required this.transactionId,
    required this.type,
    required this.direction,
    required this.currency,
    required this.amountMinor,
    required this.status,
    required this.occurredAtUtc,
    required this.counterpartyType,
    this.counterpartyReferenceSuffix,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, const {
      'transactionId',
      'type',
      'direction',
      'currency',
      'amountMinor',
      'status',
      'occurredAtUtc',
      'counterpartyType',
      'counterpartyReferenceSuffix',
    });
    final transactionId = _uuid(json['transactionId']);
    final type = _type(json['type']);
    final direction = _direction(json['direction']);
    final amount = _amount(json['amountMinor']);
    final occurredAt = _utc(json['occurredAtUtc']);
    final counterpartyType = _counterpartyType(json['counterpartyType']);
    final suffix = json['counterpartyReferenceSuffix'];
    if (json['currency'] != 'PHP' ||
        json['status'] != 'COMPLETED' ||
        (suffix != null &&
            (suffix is! String ||
                !RegExp(r'^[0-9a-f]{8}$').hasMatch(suffix))) ||
        (counterpartyType == ActivityCounterpartyType.kk10pAccount &&
            suffix == null) ||
        (counterpartyType == ActivityCounterpartyType.simulatorIssuer &&
            suffix != null) ||
        (type == ActivityType.developmentFunding &&
            (direction != ActivityDirection.incoming ||
                counterpartyType !=
                    ActivityCounterpartyType.simulatorIssuer)) ||
        (type == ActivityType.internalTransfer &&
            counterpartyType != ActivityCounterpartyType.kk10pAccount)) {
      throw const FormatException('Invalid Activity item.');
    }
    return ActivityItem(
      transactionId: transactionId,
      type: type,
      direction: direction,
      currency: 'PHP',
      amountMinor: amount,
      status: 'COMPLETED',
      occurredAtUtc: occurredAt,
      counterpartyType: counterpartyType,
      counterpartyReferenceSuffix: suffix as String?,
    );
  }

  final String transactionId;
  final ActivityType type;
  final ActivityDirection direction;
  final String currency;
  final BigInt amountMinor;
  final String status;
  final DateTime occurredAtUtc;
  final ActivityCounterpartyType counterpartyType;
  final String? counterpartyReferenceSuffix;

  String get formattedAmount =>
      '${direction == ActivityDirection.incoming ? '+' : '-'}${formatPhpMinor(amountMinor)}';
  String get title => switch (type) {
    ActivityType.developmentFunding => 'Development funding',
    ActivityType.internalTransfer =>
      direction == ActivityDirection.incoming
          ? 'Transfer received'
          : 'Transfer sent',
  };
  String get counterpartyLabel => switch (counterpartyType) {
    ActivityCounterpartyType.simulatorIssuer => 'Simulator issuer',
    ActivityCounterpartyType.kk10pAccount =>
      'Account •••• ${counterpartyReferenceSuffix?.substring(4) ?? ''}',
  };
}

class ActivityPage {
  const ActivityPage({required this.items, this.nextCursor});

  factory ActivityPage.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, const {'items', 'nextCursor'});
    final rawItems = json['items'];
    final rawCursor = json['nextCursor'];
    if (rawItems is! List ||
        rawItems.length > 50 ||
        (rawCursor != null &&
            (rawCursor is! String ||
                rawCursor.isEmpty ||
                rawCursor.length > 64 ||
                !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(rawCursor)))) {
      throw const FormatException('Invalid Activity page.');
    }
    final items = rawItems
        .map((value) {
          if (value is! Map<String, dynamic>) {
            throw const FormatException('Invalid Activity item.');
          }
          return ActivityItem.fromJson(value);
        })
        .toList(growable: false);
    if (items.map((item) => item.transactionId).toSet().length !=
        items.length) {
      throw const FormatException('Duplicate Activity item.');
    }
    return ActivityPage(items: items, nextCursor: rawCursor as String?);
  }

  final List<ActivityItem> items;
  final String? nextCursor;
}

class ActivityDetail {
  const ActivityDetail({
    required this.transactionId,
    required this.type,
    required this.direction,
    required this.currency,
    required this.amountMinor,
    required this.status,
    required this.occurredAtUtc,
    required this.accountReference,
    required this.counterpartyType,
    this.counterpartyAccountReference,
  });

  factory ActivityDetail.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, const {
      'transactionId',
      'type',
      'direction',
      'currency',
      'amountMinor',
      'status',
      'occurredAtUtc',
      'accountReference',
      'counterpartyType',
      'counterpartyAccountReference',
    });
    final counterpartyType = _counterpartyType(json['counterpartyType']);
    final counterparty = json['counterpartyAccountReference'];
    final type = _type(json['type']);
    final direction = _direction(json['direction']);
    if (json['currency'] != 'PHP' ||
        json['status'] != 'COMPLETED' ||
        (counterpartyType == ActivityCounterpartyType.kk10pAccount &&
            counterparty == null) ||
        (counterpartyType == ActivityCounterpartyType.simulatorIssuer &&
            counterparty != null) ||
        (type == ActivityType.developmentFunding &&
            (direction != ActivityDirection.incoming ||
                counterpartyType !=
                    ActivityCounterpartyType.simulatorIssuer)) ||
        (type == ActivityType.internalTransfer &&
            counterpartyType != ActivityCounterpartyType.kk10pAccount)) {
      throw const FormatException('Invalid Activity detail.');
    }
    return ActivityDetail(
      transactionId: _uuid(json['transactionId']),
      type: type,
      direction: direction,
      currency: 'PHP',
      amountMinor: _amount(json['amountMinor']),
      status: 'COMPLETED',
      occurredAtUtc: _utc(json['occurredAtUtc']),
      accountReference: _uuid(json['accountReference']),
      counterpartyType: counterpartyType,
      counterpartyAccountReference: counterparty == null
          ? null
          : _uuid(counterparty),
    );
  }

  final String transactionId;
  final ActivityType type;
  final ActivityDirection direction;
  final String currency;
  final BigInt amountMinor;
  final String status;
  final DateTime occurredAtUtc;
  final String accountReference;
  final ActivityCounterpartyType counterpartyType;
  final String? counterpartyAccountReference;

  String get formattedAmount =>
      '${direction == ActivityDirection.incoming ? '+' : '-'}${formatPhpMinor(amountMinor)}';
}

String formatPhpMinor(BigInt minor) {
  final whole = minor ~/ BigInt.from(100);
  final cents = (minor % BigInt.from(100)).toString().padLeft(2, '0');
  final digits = whole.toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return 'PHP $grouped.$cents';
}

void _requireKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(json.keys.toSet()).isNotEmpty) {
    throw const FormatException('Unexpected Activity response shape.');
  }
}

String _uuid(Object? value) {
  if (value is! String ||
      !canonicalUuidPattern.hasMatch(value) ||
      value == zeroUuid) {
    throw const FormatException('Invalid UUID.');
  }
  return value;
}

BigInt _amount(Object? value) {
  if (value is! String || !RegExp(r'^[1-9][0-9]*$').hasMatch(value)) {
    throw const FormatException('Invalid amount.');
  }
  return BigInt.parse(value);
}

DateTime _utc(Object? value) {
  final parsed = value is String && value.endsWith('Z')
      ? DateTime.tryParse(value)
      : null;
  if (parsed == null || !parsed.isUtc) {
    throw const FormatException('Invalid timestamp.');
  }
  return parsed;
}

ActivityType _type(Object? value) => switch (value) {
  'DEVELOPMENT_FUNDING' => ActivityType.developmentFunding,
  'INTERNAL_TRANSFER' => ActivityType.internalTransfer,
  _ => throw const FormatException('Invalid Activity type.'),
};

ActivityDirection _direction(Object? value) => switch (value) {
  'INCOMING' => ActivityDirection.incoming,
  'OUTGOING' => ActivityDirection.outgoing,
  _ => throw const FormatException('Invalid Activity direction.'),
};

ActivityCounterpartyType _counterpartyType(Object? value) => switch (value) {
  'KK10P_ACCOUNT' => ActivityCounterpartyType.kk10pAccount,
  'SIMULATOR_ISSUER' => ActivityCounterpartyType.simulatorIssuer,
  _ => throw const FormatException('Invalid counterparty type.'),
};

String activityTypeQuery(ActivityType value) => switch (value) {
  ActivityType.developmentFunding => 'DEVELOPMENT_FUNDING',
  ActivityType.internalTransfer => 'INTERNAL_TRANSFER',
};

String activityDirectionQuery(ActivityDirection value) => switch (value) {
  ActivityDirection.incoming => 'INCOMING',
  ActivityDirection.outgoing => 'OUTGOING',
};
