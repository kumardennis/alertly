typedef JsonMap = Map<String, dynamic>;

class ParseException implements Exception {
  ParseException(this.message);

  final String message;

  @override
  String toString() => 'ParseException: $message';
}

class TypedMap {
  TypedMap(this._value, {this.context = 'json'});

  final JsonMap _value;
  final String context;

  String reqString(String key) {
    final value = _value[key];
    if (value is String) {
      return value;
    }
    throw ParseException('$context.$key must be String');
  }

  String? optString(String key) {
    final value = _value[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    throw ParseException('$context.$key must be String?');
  }

  int reqInt(String key) {
    final value = _value[key];
    if (value is int) {
      return value;
    }
    throw ParseException('$context.$key must be int');
  }

  int? optInt(String key) {
    final value = _value[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    throw ParseException('$context.$key must be int?');
  }

  bool reqBool(String key) {
    final value = _value[key];
    if (value is bool) {
      return value;
    }
    throw ParseException('$context.$key must be bool');
  }

  bool? optBool(String key) {
    final value = _value[key];
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    throw ParseException('$context.$key must be bool?');
  }

  DateTime reqDateTime(String key) {
    final value = reqString(key);
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
    throw ParseException('$context.$key must be valid ISO datetime');
  }

  DateTime? optDateTime(String key) {
    final value = _value[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw ParseException('$context.$key must be valid ISO datetime?');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
    throw ParseException('$context.$key must be valid ISO datetime?');
  }

  Object reqObject(String key) {
    final value = _value[key];
    if (value == null) {
      throw ParseException('$context.$key must be non-null Object');
    }
    return value;
  }

  Object? optObject(String key) {
    if (!_value.containsKey(key)) {
      return null;
    }
    return _value[key];
  }

  T req<T>(String key, T Function(Object? value) parser) {
    if (!_value.containsKey(key)) {
      throw ParseException('$context.$key is missing');
    }
    return parser(_value[key]);
  }

  T? opt<T>(String key, T Function(Object? value) parser) {
    final value = _value[key];
    if (value == null) {
      return null;
    }
    return parser(value);
  }
}

JsonMap asJsonMap(Object? value, {String context = 'value'}) {
  if (value is JsonMap) {
    return value;
  }
  throw ParseException('$context must be a JSON object');
}

List<JsonMap> asJsonMapList(Object? value, {String context = 'value'}) {
  if (value is! List) {
    throw ParseException('$context must be a JSON array');
  }

  return value.map((item) => asJsonMap(item, context: '$context[]')).toList();
}
