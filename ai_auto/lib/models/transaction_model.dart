/// Transaction Model
class Transaction {
  final String id;
  final double amount;
  final String category;
  final String note;
  final DateTime date;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Transaction({
    required this.id,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    this.createdAt,
    this.updatedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      category: json['category'] ?? 'Other',
      note: json['note'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String().split('T')[0],
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  String get formattedAmount {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}đ';
  }

  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Monthly Summary Model
class MonthlySummary {
  final String period;
  final double total;
  final String totalFormatted;
  final int transactionCount;
  final List<CategorySummary> summary;

  MonthlySummary({
    required this.period,
    required this.total,
    required this.totalFormatted,
    required this.transactionCount,
    required this.summary,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    return MonthlySummary(
      period: json['period'] ?? '',
      total: (json['total'] ?? 0).toDouble(),
      totalFormatted: json['totalFormatted'] ?? '0đ',
      transactionCount: json['count'] ?? 0,
      summary: (json['summary'] as List?)
          ?.map((item) => CategorySummary.fromJson(item))
          .toList() ?? [],
    );
  }
}

/// Category Summary Model
class CategorySummary {
  final String category;
  final double total;
  final String totalFormatted;
  final int count;

  CategorySummary({
    required this.category,
    required this.total,
    required this.totalFormatted,
    required this.count,
  });

  factory CategorySummary.fromJson(Map<String, dynamic> json) {
    return CategorySummary(
      category: json['category'] ?? '',
      total: (json['total'] ?? 0).toDouble(),
      totalFormatted: json['totalFormatted'] ?? '0đ',
      count: json['count'] ?? 0,
    );
  }
}

/// Health Response Model
class HealthResponse {
  final String status;
  final String message;
  final DateTime timestamp;
  final double uptime;

  HealthResponse({
    required this.status,
    required this.message,
    required this.timestamp,
    required this.uptime,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      uptime: (json['uptime'] ?? 0).toDouble(),
    );
  }
}

/// API Status Model
class ApiStatus {
  final String service;
  final String version;
  final String agent;
  final List<String> features;

  ApiStatus({
    required this.service,
    required this.version,
    required this.agent,
    required this.features,
  });

  factory ApiStatus.fromJson(Map<String, dynamic> json) {
    return ApiStatus(
      service: json['service'] ?? '',
      version: json['version'] ?? '',
      agent: json['agent'] ?? '',
      features: List<String>.from(json['features'] ?? []),
    );
  }
}
