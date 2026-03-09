class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({required this.message, this.statusCode, this.data});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({String message = 'Oturum süresi doldu'})
      : super(message: message, statusCode: 401);
}

class NetworkException extends ApiException {
  NetworkException({String message = 'Bağlantı hatası'})
      : super(message: message);
}

class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;
  ValidationException({String message = 'Doğrulama hatası', this.errors})
      : super(message: message, statusCode: 422);
}
