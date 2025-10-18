library json_builder;

import 'dart:convert' show json;
import 'dart:io';

import 'package:path/path.dart' as path;

import 'extra_key_value.dart';

class JsonBuilder {
  List<ExtractedHeader> localeMessageHeaderList = [];
  ExtractedHeader? jsonKeyHeader;

  // <Header, FileName>
  Map<String, String> localeFileNameMap = {};

  // <Header, Map>
  Map<String, Map> localeStringBuilderMap = {};

  Map<String, bool> isLocaleFirstWriteMap = {};

  // List of keys marked for Android platform
  List<String> androidKeys = [];

  bool initialize(List<ExtractedHeader> allHeaders) {
    jsonKeyHeader = _pullJsonKeyHeaderFromList(allHeaders);
    localeMessageHeaderList = allHeaders;
    _buildLocaleMap();
    return isInitialized();
  }

  bool isInitialized() {
    return null != jsonKeyHeader && localeMessageHeaderList.isNotEmpty;
  }

  String getJsonKeyHeader() {
    return jsonKeyHeader!.header;
  }

  List<ExtractedHeader> getMessageLocaleHeaderList() {
    return localeMessageHeaderList;
  }

  void writeData(String? jsonKey, String localeHeader, String message) {
    Map? localeBuilder = localeStringBuilderMap[localeHeader];
    if (null != localeBuilder) {
      List<String> keys = jsonKey!.split(".");
      Map? root = localeBuilder;
      int lastIndex = keys.length - 1;
      for (int i = 0; i < keys.length; i++) {
        String key = keys[i];
        if (i != lastIndex) {
          if (null == root![key]) {
            root[key] = {};
          }
          root = root[key];
        } else {
          root![key] = message;
        }
      }
    }
  }

  void addAndroidKey(String? jsonKey) {
    if (null != jsonKey && !androidKeys.contains(jsonKey)) {
      androidKeys.add(jsonKey);
    }
  }

  void generateFiles(String? outputDir) {
    Directory current = Directory.current;

    for (MapEntry<String, String> fileEntry in localeFileNameMap.entries) {
      // Create File
      File generatedFile =
          File(path.join(current.path, outputDir, fileEntry.value));
      if (!generatedFile.existsSync()) {
        generatedFile.createSync(recursive: true);
      }

      Map? localeBuilder = localeStringBuilderMap[fileEntry.key];
      // Generate File
      generatedFile.writeAsStringSync(json.encode(localeBuilder));
    }

    // Generate android_strings.json if there are Android-specific keys
    if (androidKeys.isNotEmpty) {
      File androidFile =
          File(path.join(current.path, outputDir, 'android_strings.json'));
      if (!androidFile.existsSync()) {
        androidFile.createSync(recursive: true);
      }
      androidFile.writeAsStringSync(json.encode({'keys': androidKeys}));
    }
  }

  ExtractedHeader? _pullJsonKeyHeaderFromList(List<ExtractedHeader> headers) {
    for (ExtractedHeader header in headers) {
      if (ContentType.key == header.type) {
        headers.remove(header);
        return header;
      }
    }
    return null;
  }

  void _buildLocaleMap() {
    for (ExtractedHeader localeHeader in localeMessageHeaderList) {
      isLocaleFirstWriteMap[localeHeader.header] = true;
      localeFileNameMap[localeHeader.header] =
          'string_${localeHeader.code}.json';
      localeStringBuilderMap[localeHeader.header] = {};
    }
  }
}
