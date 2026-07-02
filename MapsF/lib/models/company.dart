class Company {
  const Company({
    required this.id,
    required this.name,
    this.legalName,
    this.identifier,
  });

  final String id;
  final String name;
  final String? legalName;
  final String? identifier;

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'].toString(),
      name: json['name'].toString(),
      legalName: json['legal_name']?.toString(),
      identifier: json['identifier']?.toString(),
    );
  }
}
