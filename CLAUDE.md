# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

lang_table is a Dart plugin that generates localization string files from table-based sources (like Airtable). It downloads multi-language strings from a configured platform and generates JSON files for Flutter applications.

## Core Commands

### Generate Localization Files
```bash
# Basic command structure
dart bin/generate.dart --platform=airTable --input=<AIRTABLE_URL> --api-key=<API_KEY> --target=Flutter

# With custom output directory
dart bin/generate.dart --platform=airTable --input=<AIRTABLE_URL> --api-key=<API_KEY> --target=Flutter --output-dir=custom/path

# Get help
dart bin/generate.dart --help
```

### Development Commands
```bash
# Get dependencies
dart pub get

# Run the example app (Flutter)
cd example
flutter pub get
flutter run
```

## Architecture

### Entry Point Flow
1. **bin/generate.dart**: Command-line entry point that parses arguments and routes to appropriate generator
2. **lib/lang_table.dart**: Contains core configuration model (`ConfigOption`) and factory pattern for platform generators
3. **Platform Generators**: Implement `PlatformGenerator` interface (currently only `AirTableGenerator`)

### Key Components

**ConfigOption** (lib/lang_table.dart:5-16)
- Holds all configuration passed from command line: platform, input URL, API key, output directory, target

**PlatformGenerator Interface** (lib/lang_table.dart:18-21)
- `build(ConfigOption config)`: Main execution method for fetching and generating files
- `validArguments(ConfigOption config)`: Validates required arguments before execution

**AirTableGenerator** (lib/src/generator/airtable_generator.dart)
- Fetches data from Airtable API with pagination (5 requests/sec rate limit enforced)
- Extracts headers with meta code patterns like `[code=key]` and `[code=en]`
- Processes records and delegates to JsonBuilder for file generation

**JsonBuilder** (lib/src/json_builder.dart)
- Manages locale-to-filename mapping (e.g., `en` -> `string_en.json`)
- Supports nested keys using dot notation (e.g., `group.hello` -> `{"group": {"hello": "..."}}``)
- Writes JSON files to output directory

**ExtractedHeader** (lib/src/extra_key_value.dart)
- Parses table column headers to identify their purpose using regex `\[code=.*\]`
- `ContentType.key`: Column containing message keys
- `ContentType.value`: Column containing localized messages (code = locale like `en`, `ja`, `zh_TW`)

### Data Flow
1. Command-line args -> ConfigOption
2. Factory creates appropriate PlatformGenerator (currently only AirTable)
3. Generator validates arguments and fetches data with pagination
4. First record's headers are parsed to identify key column and locale columns
5. Records are processed and added to JsonBuilder's nested maps
6. JsonBuilder generates one JSON file per locale in output directory

## Meta Code System

Table column headers must include meta codes to identify their purpose:
- `[code=key]`: Identifies the column storing message keys
- `[code=en]`, `[code=ja]`, `[code=zh_TW]`, etc.: Identifies columns for specific locales

## Supported Platforms

Currently only **AirTable** is supported. To add new platforms:
1. Create a new generator class implementing `PlatformGenerator` in `lib/src/generator/`
2. Add the platform to `platformGeneratorFactory()` in `lib/lang_table.dart:23-28`

## Important Notes

- The project uses null safety (SDK: `>=2.12.0 <4.0.0`)
- AirTable rate limit is 5 requests/second (enforced via 220ms sleep in airtable_generator.dart:50-51)
- Output directory defaults to `res/string` if not specified
- Only Flutter is currently supported as a target platform
- Generated files follow the pattern: `string_{locale}.json`