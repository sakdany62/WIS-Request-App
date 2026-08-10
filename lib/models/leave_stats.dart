class LeaveStats {
  final int total;
  final int used;
  final int remaining;
  final int pending;
  final int approved;
  final int rejected;
  final int autoApproved;

  LeaveStats({
    this.total = 24,
    this.used = 0,
    this.remaining = 24,
    this.pending = 0,
    this.approved = 0,
    this.rejected = 0,
    this.autoApproved = 0,
  });

  factory LeaveStats.fromMap(Map<String, int> map) {
    return LeaveStats(
      total: map['total'] ?? 24,
      used: map['used'] ?? 0,
      remaining: map['remaining'] ?? 24,
      pending: map['pending'] ?? 0,
      approved: map['approved'] ?? 0,
      rejected: map['rejected'] ?? 0,
      autoApproved: map['autoApproved'] ?? 0,
    );
  }

  Map<String, int> toMap() {
    return {
      'total': total,
      'used': used,
      'remaining': remaining,
      'pending': pending,
      'approved': approved,
      'rejected': rejected,
      'autoApproved': autoApproved,
    };
  }

  LeaveStats copyWith({
    int? total,
    int? used,
    int? remaining,
    int? pending,
    int? approved,
    int? rejected,
    int? autoApproved,
  }) {
    return LeaveStats(
      total: total ?? this.total,
      used: used ?? this.used,
      remaining: remaining ?? this.remaining,
      pending: pending ?? this.pending,
      approved: approved ?? this.approved,
      rejected: rejected ?? this.rejected,
      autoApproved: autoApproved ?? this.autoApproved,
    );
  }

  static LeaveStats calculate(List<Map<String, dynamic>> requests) {
    int totalDays = 0;
    int pending = 0;
    int approved = 0;
    int rejected = 0;
    int autoApproved = 0;

    for (var request in requests) {
      final status = request['status'] ?? 'pending';
      final days = (request['totalDays'] as num?)?.toInt() ?? 0;
      final isAutoApproved = request['autoApproved'] ?? false;

      if (status == 'approved') {
        approved++;
        totalDays += days;
        if (isAutoApproved) autoApproved++;
      } else if (status == 'pending') {
        pending++;
      } else if (status == 'rejected') {
        rejected++;
      }
    }

    final remaining = 24 - totalDays;

    return LeaveStats(
      total: 24,
      used: totalDays,
      remaining: remaining < 0 ? 0 : remaining,
      pending: pending,
      approved: approved,
      rejected: rejected,
      autoApproved: autoApproved,
    );
  }
}