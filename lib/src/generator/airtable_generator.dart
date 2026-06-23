library airtable_generator;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../lang_table.dart';
import '../extra_key_value.dart';
import '../json_builder.dart';
import '../print_tool.dart';

class AirTableGenerator implements PlatformGenerator {
  @override
  void build(ConfigOption config) async {
    Map<String, String> headers = {};
    headers['Authorization'] = 'Bearer ${config.apiKey}';

    var offset;
    bool isError = false;

    JsonBuilder jsonBuilder = JsonBuilder();

    do {
      var offsetParama = '';
      if (null != offset) {
        offsetParama = '?offset=${offset}';
      }

      var response = await http.get(Uri.parse('${config.input}${offsetParama}'),
          headers: headers);

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);

        offset = jsonResponse['offset'];
        List<dynamic> records = jsonResponse['records'];

        if (records.length > 0) {
          if (!jsonBuilder.isInitialized()) {
            bool isSuccess =
                jsonBuilder.initialize(extractHeaderList(records[1]));
            if (!isSuccess) {
              printError("Missing Json Key Header or Locale headers");
              isError = true;
              break;
            }
          }
          processRecords(jsonBuilder, records);
          sleep(
              Duration(milliseconds: 220)); // Rate Limit : 5 request per second
        }
      } else {
        printError("Request failed with status: ${response.statusCode}.");
        printError("Request Message : ${response.body}.");
        isError = true;
        break;
      }
    } while (offset != null);

    if (!isError) {
      // Generate Code
      jsonBuilder.generateFiles(config.outputDir);
      printInfo('Success to generate files');
    }
  }

  @override
  String? validArguments(ConfigOption config) {
    if (null == config.apiKey) {
      return 'Argument "api-key" is missing';
    }

    if (config.target != 'Flutter') {
      return 'platform [${config.platform}] does not support the target [${config.target}]';
    }
    return null;
  }

  // Table authors hand-write control characters inside a cell as escape
  // sequences (`\n`, `\r`, `\t`, ` `, ...) and sometimes double the
  // backslash (`\\n`). Interpret one or two leading backslashes followed by a
  // known escape body into the real character, so the generated JSON holds
  // actual data and no shell post-processing (sed) is needed downstream.
  static final RegExp _escapeSequence =
      RegExp(r'\\{1,2}(n|r|t|u[0-9A-Fa-f]{4})');

  String normalizeEscapeSequences(String message) {
    return message.replaceAllMapped(_escapeSequence, (match) {
      String body = match.group(1)!;
      switch (body[0]) {
        case 'n':
          return '\n';
        case 'r':
          return '\r';
        case 't':
          return '\t';
        case 'u':
          return String.fromCharCode(int.parse(body.substring(1), radix: 16));
      }
      return match.group(0)!;
    });
  }

  List<ExtractedHeader> extractHeaderList(record) {
    List<ExtractedHeader> headers = [];

    Map<String, dynamic> fields = record['fields'];
    for (String jsonKey in fields.keys) {
      ExtractedHeader extractedHeader = convertToExtractedHeader(jsonKey);
      if (ContentType.none != extractedHeader.type) {
        headers.add(extractedHeader);
      }
    }
    return headers;
  }

  void processRecords(JsonBuilder jsonBuilder, List<dynamic> records) {
    String jsonKeyHeader = jsonBuilder.getJsonKeyHeader();
    List<ExtractedHeader> localeHeaderList =
        jsonBuilder.getMessageLocaleHeaderList();

    for (dynamic record in records) {
      Map<String, dynamic> fields = record['fields'];
      if (fields.isEmpty) {
        continue;
      }

      // Check Notes field for special markers
      dynamic notes = fields['Notes'];
      bool isAndroidKey = false;
      bool isIosKey = false;
      bool isWebKey = false;

      if (notes != null) {
        String notesStr = notes.toString();

        // Skip records with Notes starting with "DEL"
        if (notesStr.startsWith('DEL')) {
          continue;
        }

        // Check if this key is marked for Android
        if (notesStr.contains('__android__')) {
          isAndroidKey = true;
        }

        // Check if this key is marked for iOS
        if (notesStr.contains('__ios__')) {
          isIosKey = true;
        }

        // Check if this key is marked for Web
        if (notesStr.contains('__web__')) {
          isWebKey = true;
        }
      }

      String? jsonKey = fields[jsonKeyHeader];

      // Add to Android keys list if marked
      if (isAndroidKey) {
        jsonBuilder.addAndroidKey(jsonKey);
      }

      // Add to iOS keys list if marked
      if (isIosKey) {
        jsonBuilder.addIosKey(jsonKey);
      }

      // Add to Web keys list if marked
      if (isWebKey) {
        jsonBuilder.addWebKey(jsonKey);
      }

      for (ExtractedHeader localeHeader in localeHeaderList) {
        dynamic message = fields[localeHeader.header];
        if (message is List) {
          message = message[0];
        }

        if (null != message) {
          if (message is String) {
            message = normalizeEscapeSequences(message);
          }
          jsonBuilder.writeData(jsonKey, localeHeader.header, message);
        }
      }
    }
  }
}
