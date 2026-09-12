// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_db.dart';

// ignore_for_file: type=lint
class $PacksTable extends Packs with TableInfo<$PacksTable, Pack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PacksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectNameMeta = const VerificationMeta(
    'subjectName',
  );
  @override
  late final GeneratedColumn<String> subjectName = GeneratedColumn<String>(
    'subject_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _examIdMeta = const VerificationMeta('examId');
  @override
  late final GeneratedColumn<String> examId = GeneratedColumn<String>(
    'exam_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _examSlugMeta = const VerificationMeta(
    'examSlug',
  );
  @override
  late final GeneratedColumn<String> examSlug = GeneratedColumn<String>(
    'exam_slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _examShortMeta = const VerificationMeta(
    'examShort',
  );
  @override
  late final GeneratedColumn<String> examShort = GeneratedColumn<String>(
    'exam_short',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    subjectId,
    subjectName,
    examId,
    examSlug,
    examShort,
    count,
    downloadedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'packs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('subject_name')) {
      context.handle(
        _subjectNameMeta,
        subjectName.isAcceptableOrUnknown(
          data['subject_name']!,
          _subjectNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectNameMeta);
    }
    if (data.containsKey('exam_id')) {
      context.handle(
        _examIdMeta,
        examId.isAcceptableOrUnknown(data['exam_id']!, _examIdMeta),
      );
    } else if (isInserting) {
      context.missing(_examIdMeta);
    }
    if (data.containsKey('exam_slug')) {
      context.handle(
        _examSlugMeta,
        examSlug.isAcceptableOrUnknown(data['exam_slug']!, _examSlugMeta),
      );
    } else if (isInserting) {
      context.missing(_examSlugMeta);
    }
    if (data.containsKey('exam_short')) {
      context.handle(
        _examShortMeta,
        examShort.isAcceptableOrUnknown(data['exam_short']!, _examShortMeta),
      );
    } else if (isInserting) {
      context.missing(_examShortMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {subjectId};
  @override
  Pack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pack(
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      subjectName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_name'],
      )!,
      examId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exam_id'],
      )!,
      examSlug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exam_slug'],
      )!,
      examShort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exam_short'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      )!,
    );
  }

  @override
  $PacksTable createAlias(String alias) {
    return $PacksTable(attachedDatabase, alias);
  }
}

class Pack extends DataClass implements Insertable<Pack> {
  final String subjectId;
  final String subjectName;
  final String examId;
  final String examSlug;
  final String examShort;
  final int count;
  final DateTime downloadedAt;
  const Pack({
    required this.subjectId,
    required this.subjectName,
    required this.examId,
    required this.examSlug,
    required this.examShort,
    required this.count,
    required this.downloadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['subject_id'] = Variable<String>(subjectId);
    map['subject_name'] = Variable<String>(subjectName);
    map['exam_id'] = Variable<String>(examId);
    map['exam_slug'] = Variable<String>(examSlug);
    map['exam_short'] = Variable<String>(examShort);
    map['count'] = Variable<int>(count);
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    return map;
  }

  PacksCompanion toCompanion(bool nullToAbsent) {
    return PacksCompanion(
      subjectId: Value(subjectId),
      subjectName: Value(subjectName),
      examId: Value(examId),
      examSlug: Value(examSlug),
      examShort: Value(examShort),
      count: Value(count),
      downloadedAt: Value(downloadedAt),
    );
  }

  factory Pack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pack(
      subjectId: serializer.fromJson<String>(json['subjectId']),
      subjectName: serializer.fromJson<String>(json['subjectName']),
      examId: serializer.fromJson<String>(json['examId']),
      examSlug: serializer.fromJson<String>(json['examSlug']),
      examShort: serializer.fromJson<String>(json['examShort']),
      count: serializer.fromJson<int>(json['count']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'subjectId': serializer.toJson<String>(subjectId),
      'subjectName': serializer.toJson<String>(subjectName),
      'examId': serializer.toJson<String>(examId),
      'examSlug': serializer.toJson<String>(examSlug),
      'examShort': serializer.toJson<String>(examShort),
      'count': serializer.toJson<int>(count),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
    };
  }

  Pack copyWith({
    String? subjectId,
    String? subjectName,
    String? examId,
    String? examSlug,
    String? examShort,
    int? count,
    DateTime? downloadedAt,
  }) => Pack(
    subjectId: subjectId ?? this.subjectId,
    subjectName: subjectName ?? this.subjectName,
    examId: examId ?? this.examId,
    examSlug: examSlug ?? this.examSlug,
    examShort: examShort ?? this.examShort,
    count: count ?? this.count,
    downloadedAt: downloadedAt ?? this.downloadedAt,
  );
  Pack copyWithCompanion(PacksCompanion data) {
    return Pack(
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      subjectName: data.subjectName.present
          ? data.subjectName.value
          : this.subjectName,
      examId: data.examId.present ? data.examId.value : this.examId,
      examSlug: data.examSlug.present ? data.examSlug.value : this.examSlug,
      examShort: data.examShort.present ? data.examShort.value : this.examShort,
      count: data.count.present ? data.count.value : this.count,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pack(')
          ..write('subjectId: $subjectId, ')
          ..write('subjectName: $subjectName, ')
          ..write('examId: $examId, ')
          ..write('examSlug: $examSlug, ')
          ..write('examShort: $examShort, ')
          ..write('count: $count, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    subjectId,
    subjectName,
    examId,
    examSlug,
    examShort,
    count,
    downloadedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pack &&
          other.subjectId == this.subjectId &&
          other.subjectName == this.subjectName &&
          other.examId == this.examId &&
          other.examSlug == this.examSlug &&
          other.examShort == this.examShort &&
          other.count == this.count &&
          other.downloadedAt == this.downloadedAt);
}

class PacksCompanion extends UpdateCompanion<Pack> {
  final Value<String> subjectId;
  final Value<String> subjectName;
  final Value<String> examId;
  final Value<String> examSlug;
  final Value<String> examShort;
  final Value<int> count;
  final Value<DateTime> downloadedAt;
  final Value<int> rowid;
  const PacksCompanion({
    this.subjectId = const Value.absent(),
    this.subjectName = const Value.absent(),
    this.examId = const Value.absent(),
    this.examSlug = const Value.absent(),
    this.examShort = const Value.absent(),
    this.count = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PacksCompanion.insert({
    required String subjectId,
    required String subjectName,
    required String examId,
    required String examSlug,
    required String examShort,
    required int count,
    required DateTime downloadedAt,
    this.rowid = const Value.absent(),
  }) : subjectId = Value(subjectId),
       subjectName = Value(subjectName),
       examId = Value(examId),
       examSlug = Value(examSlug),
       examShort = Value(examShort),
       count = Value(count),
       downloadedAt = Value(downloadedAt);
  static Insertable<Pack> custom({
    Expression<String>? subjectId,
    Expression<String>? subjectName,
    Expression<String>? examId,
    Expression<String>? examSlug,
    Expression<String>? examShort,
    Expression<int>? count,
    Expression<DateTime>? downloadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (subjectId != null) 'subject_id': subjectId,
      if (subjectName != null) 'subject_name': subjectName,
      if (examId != null) 'exam_id': examId,
      if (examSlug != null) 'exam_slug': examSlug,
      if (examShort != null) 'exam_short': examShort,
      if (count != null) 'count': count,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PacksCompanion copyWith({
    Value<String>? subjectId,
    Value<String>? subjectName,
    Value<String>? examId,
    Value<String>? examSlug,
    Value<String>? examShort,
    Value<int>? count,
    Value<DateTime>? downloadedAt,
    Value<int>? rowid,
  }) {
    return PacksCompanion(
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      examId: examId ?? this.examId,
      examSlug: examSlug ?? this.examSlug,
      examShort: examShort ?? this.examShort,
      count: count ?? this.count,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (subjectName.present) {
      map['subject_name'] = Variable<String>(subjectName.value);
    }
    if (examId.present) {
      map['exam_id'] = Variable<String>(examId.value);
    }
    if (examSlug.present) {
      map['exam_slug'] = Variable<String>(examSlug.value);
    }
    if (examShort.present) {
      map['exam_short'] = Variable<String>(examShort.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PacksCompanion(')
          ..write('subjectId: $subjectId, ')
          ..write('subjectName: $subjectName, ')
          ..write('examId: $examId, ')
          ..write('examSlug: $examSlug, ')
          ..write('examShort: $examShort, ')
          ..write('count: $count, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VaultQuestionsTable extends VaultQuestions
    with TableInfo<$VaultQuestionsTable, VaultQuestion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultQuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionHtmlMeta = const VerificationMeta(
    'questionHtml',
  );
  @override
  late final GeneratedColumn<String> questionHtml = GeneratedColumn<String>(
    'question_html',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _optionsHtmlJsonMeta = const VerificationMeta(
    'optionsHtmlJson',
  );
  @override
  late final GeneratedColumn<String> optionsHtmlJson = GeneratedColumn<String>(
    'options_html_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _explanationHtmlMeta = const VerificationMeta(
    'explanationHtml',
  );
  @override
  late final GeneratedColumn<String> explanationHtml = GeneratedColumn<String>(
    'explanation_html',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _optionsJsonMeta = const VerificationMeta(
    'optionsJson',
  );
  @override
  late final GeneratedColumn<String> optionsJson = GeneratedColumn<String>(
    'options_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lettersJsonMeta = const VerificationMeta(
    'lettersJson',
  );
  @override
  late final GeneratedColumn<String> lettersJson = GeneratedColumn<String>(
    'letters_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passageIdMeta = const VerificationMeta(
    'passageId',
  );
  @override
  late final GeneratedColumn<String> passageId = GeneratedColumn<String>(
    'passage_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionMeta = const VerificationMeta(
    'section',
  );
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
    'section',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _explanationMeta = const VerificationMeta(
    'explanation',
  );
  @override
  late final GeneratedColumn<String> explanation = GeneratedColumn<String>(
    'explanation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaJsonMeta = const VerificationMeta(
    'mediaJson',
  );
  @override
  late final GeneratedColumn<String> mediaJson = GeneratedColumn<String>(
    'media_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    question,
    questionHtml,
    optionsHtmlJson,
    explanationHtml,
    optionsJson,
    lettersJson,
    passageId,
    section,
    year,
    answer,
    explanation,
    mediaJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultQuestion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('question_html')) {
      context.handle(
        _questionHtmlMeta,
        questionHtml.isAcceptableOrUnknown(
          data['question_html']!,
          _questionHtmlMeta,
        ),
      );
    }
    if (data.containsKey('options_html_json')) {
      context.handle(
        _optionsHtmlJsonMeta,
        optionsHtmlJson.isAcceptableOrUnknown(
          data['options_html_json']!,
          _optionsHtmlJsonMeta,
        ),
      );
    }
    if (data.containsKey('explanation_html')) {
      context.handle(
        _explanationHtmlMeta,
        explanationHtml.isAcceptableOrUnknown(
          data['explanation_html']!,
          _explanationHtmlMeta,
        ),
      );
    }
    if (data.containsKey('options_json')) {
      context.handle(
        _optionsJsonMeta,
        optionsJson.isAcceptableOrUnknown(
          data['options_json']!,
          _optionsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_optionsJsonMeta);
    }
    if (data.containsKey('letters_json')) {
      context.handle(
        _lettersJsonMeta,
        lettersJson.isAcceptableOrUnknown(
          data['letters_json']!,
          _lettersJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lettersJsonMeta);
    }
    if (data.containsKey('passage_id')) {
      context.handle(
        _passageIdMeta,
        passageId.isAcceptableOrUnknown(data['passage_id']!, _passageIdMeta),
      );
    }
    if (data.containsKey('section')) {
      context.handle(
        _sectionMeta,
        section.isAcceptableOrUnknown(data['section']!, _sectionMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    }
    if (data.containsKey('explanation')) {
      context.handle(
        _explanationMeta,
        explanation.isAcceptableOrUnknown(
          data['explanation']!,
          _explanationMeta,
        ),
      );
    }
    if (data.containsKey('media_json')) {
      context.handle(
        _mediaJsonMeta,
        mediaJson.isAcceptableOrUnknown(data['media_json']!, _mediaJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultQuestion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultQuestion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      question: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question'],
      )!,
      questionHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_html'],
      ),
      optionsHtmlJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}options_html_json'],
      ),
      explanationHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation_html'],
      ),
      optionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}options_json'],
      )!,
      lettersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}letters_json'],
      )!,
      passageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}passage_id'],
      ),
      section: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
      ),
      explanation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation'],
      ),
      mediaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_json'],
      ),
    );
  }

  @override
  $VaultQuestionsTable createAlias(String alias) {
    return $VaultQuestionsTable(attachedDatabase, alias);
  }
}

class VaultQuestion extends DataClass implements Insertable<VaultQuestion> {
  final String id;
  final String subjectId;

  /// The READABLE text — indices as real characters, no tags. Kept because
  /// search, previews and the pending-result payload all want it.
  final String question;
  final String? questionHtml;
  final String? optionsHtmlJson;
  final String? explanationHtml;

  /// Options and letters as JSON arrays. A join table for four strings would
  /// cost more to read than it saves, and these are never queried by option.
  final String optionsJson;
  final String lettersJson;
  final String? passageId;
  final String? section;
  final int? year;
  final String? answer;
  final String? explanation;
  final String? mediaJson;
  const VaultQuestion({
    required this.id,
    required this.subjectId,
    required this.question,
    this.questionHtml,
    this.optionsHtmlJson,
    this.explanationHtml,
    required this.optionsJson,
    required this.lettersJson,
    this.passageId,
    this.section,
    this.year,
    this.answer,
    this.explanation,
    this.mediaJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['subject_id'] = Variable<String>(subjectId);
    map['question'] = Variable<String>(question);
    if (!nullToAbsent || questionHtml != null) {
      map['question_html'] = Variable<String>(questionHtml);
    }
    if (!nullToAbsent || optionsHtmlJson != null) {
      map['options_html_json'] = Variable<String>(optionsHtmlJson);
    }
    if (!nullToAbsent || explanationHtml != null) {
      map['explanation_html'] = Variable<String>(explanationHtml);
    }
    map['options_json'] = Variable<String>(optionsJson);
    map['letters_json'] = Variable<String>(lettersJson);
    if (!nullToAbsent || passageId != null) {
      map['passage_id'] = Variable<String>(passageId);
    }
    if (!nullToAbsent || section != null) {
      map['section'] = Variable<String>(section);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || answer != null) {
      map['answer'] = Variable<String>(answer);
    }
    if (!nullToAbsent || explanation != null) {
      map['explanation'] = Variable<String>(explanation);
    }
    if (!nullToAbsent || mediaJson != null) {
      map['media_json'] = Variable<String>(mediaJson);
    }
    return map;
  }

  VaultQuestionsCompanion toCompanion(bool nullToAbsent) {
    return VaultQuestionsCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      question: Value(question),
      questionHtml: questionHtml == null && nullToAbsent
          ? const Value.absent()
          : Value(questionHtml),
      optionsHtmlJson: optionsHtmlJson == null && nullToAbsent
          ? const Value.absent()
          : Value(optionsHtmlJson),
      explanationHtml: explanationHtml == null && nullToAbsent
          ? const Value.absent()
          : Value(explanationHtml),
      optionsJson: Value(optionsJson),
      lettersJson: Value(lettersJson),
      passageId: passageId == null && nullToAbsent
          ? const Value.absent()
          : Value(passageId),
      section: section == null && nullToAbsent
          ? const Value.absent()
          : Value(section),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      answer: answer == null && nullToAbsent
          ? const Value.absent()
          : Value(answer),
      explanation: explanation == null && nullToAbsent
          ? const Value.absent()
          : Value(explanation),
      mediaJson: mediaJson == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaJson),
    );
  }

  factory VaultQuestion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultQuestion(
      id: serializer.fromJson<String>(json['id']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      question: serializer.fromJson<String>(json['question']),
      questionHtml: serializer.fromJson<String?>(json['questionHtml']),
      optionsHtmlJson: serializer.fromJson<String?>(json['optionsHtmlJson']),
      explanationHtml: serializer.fromJson<String?>(json['explanationHtml']),
      optionsJson: serializer.fromJson<String>(json['optionsJson']),
      lettersJson: serializer.fromJson<String>(json['lettersJson']),
      passageId: serializer.fromJson<String?>(json['passageId']),
      section: serializer.fromJson<String?>(json['section']),
      year: serializer.fromJson<int?>(json['year']),
      answer: serializer.fromJson<String?>(json['answer']),
      explanation: serializer.fromJson<String?>(json['explanation']),
      mediaJson: serializer.fromJson<String?>(json['mediaJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'subjectId': serializer.toJson<String>(subjectId),
      'question': serializer.toJson<String>(question),
      'questionHtml': serializer.toJson<String?>(questionHtml),
      'optionsHtmlJson': serializer.toJson<String?>(optionsHtmlJson),
      'explanationHtml': serializer.toJson<String?>(explanationHtml),
      'optionsJson': serializer.toJson<String>(optionsJson),
      'lettersJson': serializer.toJson<String>(lettersJson),
      'passageId': serializer.toJson<String?>(passageId),
      'section': serializer.toJson<String?>(section),
      'year': serializer.toJson<int?>(year),
      'answer': serializer.toJson<String?>(answer),
      'explanation': serializer.toJson<String?>(explanation),
      'mediaJson': serializer.toJson<String?>(mediaJson),
    };
  }

  VaultQuestion copyWith({
    String? id,
    String? subjectId,
    String? question,
    Value<String?> questionHtml = const Value.absent(),
    Value<String?> optionsHtmlJson = const Value.absent(),
    Value<String?> explanationHtml = const Value.absent(),
    String? optionsJson,
    String? lettersJson,
    Value<String?> passageId = const Value.absent(),
    Value<String?> section = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> answer = const Value.absent(),
    Value<String?> explanation = const Value.absent(),
    Value<String?> mediaJson = const Value.absent(),
  }) => VaultQuestion(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    question: question ?? this.question,
    questionHtml: questionHtml.present ? questionHtml.value : this.questionHtml,
    optionsHtmlJson: optionsHtmlJson.present
        ? optionsHtmlJson.value
        : this.optionsHtmlJson,
    explanationHtml: explanationHtml.present
        ? explanationHtml.value
        : this.explanationHtml,
    optionsJson: optionsJson ?? this.optionsJson,
    lettersJson: lettersJson ?? this.lettersJson,
    passageId: passageId.present ? passageId.value : this.passageId,
    section: section.present ? section.value : this.section,
    year: year.present ? year.value : this.year,
    answer: answer.present ? answer.value : this.answer,
    explanation: explanation.present ? explanation.value : this.explanation,
    mediaJson: mediaJson.present ? mediaJson.value : this.mediaJson,
  );
  VaultQuestion copyWithCompanion(VaultQuestionsCompanion data) {
    return VaultQuestion(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      question: data.question.present ? data.question.value : this.question,
      questionHtml: data.questionHtml.present
          ? data.questionHtml.value
          : this.questionHtml,
      optionsHtmlJson: data.optionsHtmlJson.present
          ? data.optionsHtmlJson.value
          : this.optionsHtmlJson,
      explanationHtml: data.explanationHtml.present
          ? data.explanationHtml.value
          : this.explanationHtml,
      optionsJson: data.optionsJson.present
          ? data.optionsJson.value
          : this.optionsJson,
      lettersJson: data.lettersJson.present
          ? data.lettersJson.value
          : this.lettersJson,
      passageId: data.passageId.present ? data.passageId.value : this.passageId,
      section: data.section.present ? data.section.value : this.section,
      year: data.year.present ? data.year.value : this.year,
      answer: data.answer.present ? data.answer.value : this.answer,
      explanation: data.explanation.present
          ? data.explanation.value
          : this.explanation,
      mediaJson: data.mediaJson.present ? data.mediaJson.value : this.mediaJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultQuestion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('question: $question, ')
          ..write('questionHtml: $questionHtml, ')
          ..write('optionsHtmlJson: $optionsHtmlJson, ')
          ..write('explanationHtml: $explanationHtml, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('lettersJson: $lettersJson, ')
          ..write('passageId: $passageId, ')
          ..write('section: $section, ')
          ..write('year: $year, ')
          ..write('answer: $answer, ')
          ..write('explanation: $explanation, ')
          ..write('mediaJson: $mediaJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subjectId,
    question,
    questionHtml,
    optionsHtmlJson,
    explanationHtml,
    optionsJson,
    lettersJson,
    passageId,
    section,
    year,
    answer,
    explanation,
    mediaJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultQuestion &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.question == this.question &&
          other.questionHtml == this.questionHtml &&
          other.optionsHtmlJson == this.optionsHtmlJson &&
          other.explanationHtml == this.explanationHtml &&
          other.optionsJson == this.optionsJson &&
          other.lettersJson == this.lettersJson &&
          other.passageId == this.passageId &&
          other.section == this.section &&
          other.year == this.year &&
          other.answer == this.answer &&
          other.explanation == this.explanation &&
          other.mediaJson == this.mediaJson);
}

class VaultQuestionsCompanion extends UpdateCompanion<VaultQuestion> {
  final Value<String> id;
  final Value<String> subjectId;
  final Value<String> question;
  final Value<String?> questionHtml;
  final Value<String?> optionsHtmlJson;
  final Value<String?> explanationHtml;
  final Value<String> optionsJson;
  final Value<String> lettersJson;
  final Value<String?> passageId;
  final Value<String?> section;
  final Value<int?> year;
  final Value<String?> answer;
  final Value<String?> explanation;
  final Value<String?> mediaJson;
  final Value<int> rowid;
  const VaultQuestionsCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.question = const Value.absent(),
    this.questionHtml = const Value.absent(),
    this.optionsHtmlJson = const Value.absent(),
    this.explanationHtml = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.lettersJson = const Value.absent(),
    this.passageId = const Value.absent(),
    this.section = const Value.absent(),
    this.year = const Value.absent(),
    this.answer = const Value.absent(),
    this.explanation = const Value.absent(),
    this.mediaJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultQuestionsCompanion.insert({
    required String id,
    required String subjectId,
    required String question,
    this.questionHtml = const Value.absent(),
    this.optionsHtmlJson = const Value.absent(),
    this.explanationHtml = const Value.absent(),
    required String optionsJson,
    required String lettersJson,
    this.passageId = const Value.absent(),
    this.section = const Value.absent(),
    this.year = const Value.absent(),
    this.answer = const Value.absent(),
    this.explanation = const Value.absent(),
    this.mediaJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       subjectId = Value(subjectId),
       question = Value(question),
       optionsJson = Value(optionsJson),
       lettersJson = Value(lettersJson);
  static Insertable<VaultQuestion> custom({
    Expression<String>? id,
    Expression<String>? subjectId,
    Expression<String>? question,
    Expression<String>? questionHtml,
    Expression<String>? optionsHtmlJson,
    Expression<String>? explanationHtml,
    Expression<String>? optionsJson,
    Expression<String>? lettersJson,
    Expression<String>? passageId,
    Expression<String>? section,
    Expression<int>? year,
    Expression<String>? answer,
    Expression<String>? explanation,
    Expression<String>? mediaJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (question != null) 'question': question,
      if (questionHtml != null) 'question_html': questionHtml,
      if (optionsHtmlJson != null) 'options_html_json': optionsHtmlJson,
      if (explanationHtml != null) 'explanation_html': explanationHtml,
      if (optionsJson != null) 'options_json': optionsJson,
      if (lettersJson != null) 'letters_json': lettersJson,
      if (passageId != null) 'passage_id': passageId,
      if (section != null) 'section': section,
      if (year != null) 'year': year,
      if (answer != null) 'answer': answer,
      if (explanation != null) 'explanation': explanation,
      if (mediaJson != null) 'media_json': mediaJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultQuestionsCompanion copyWith({
    Value<String>? id,
    Value<String>? subjectId,
    Value<String>? question,
    Value<String?>? questionHtml,
    Value<String?>? optionsHtmlJson,
    Value<String?>? explanationHtml,
    Value<String>? optionsJson,
    Value<String>? lettersJson,
    Value<String?>? passageId,
    Value<String?>? section,
    Value<int?>? year,
    Value<String?>? answer,
    Value<String?>? explanation,
    Value<String?>? mediaJson,
    Value<int>? rowid,
  }) {
    return VaultQuestionsCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      question: question ?? this.question,
      questionHtml: questionHtml ?? this.questionHtml,
      optionsHtmlJson: optionsHtmlJson ?? this.optionsHtmlJson,
      explanationHtml: explanationHtml ?? this.explanationHtml,
      optionsJson: optionsJson ?? this.optionsJson,
      lettersJson: lettersJson ?? this.lettersJson,
      passageId: passageId ?? this.passageId,
      section: section ?? this.section,
      year: year ?? this.year,
      answer: answer ?? this.answer,
      explanation: explanation ?? this.explanation,
      mediaJson: mediaJson ?? this.mediaJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (questionHtml.present) {
      map['question_html'] = Variable<String>(questionHtml.value);
    }
    if (optionsHtmlJson.present) {
      map['options_html_json'] = Variable<String>(optionsHtmlJson.value);
    }
    if (explanationHtml.present) {
      map['explanation_html'] = Variable<String>(explanationHtml.value);
    }
    if (optionsJson.present) {
      map['options_json'] = Variable<String>(optionsJson.value);
    }
    if (lettersJson.present) {
      map['letters_json'] = Variable<String>(lettersJson.value);
    }
    if (passageId.present) {
      map['passage_id'] = Variable<String>(passageId.value);
    }
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (explanation.present) {
      map['explanation'] = Variable<String>(explanation.value);
    }
    if (mediaJson.present) {
      map['media_json'] = Variable<String>(mediaJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultQuestionsCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('question: $question, ')
          ..write('questionHtml: $questionHtml, ')
          ..write('optionsHtmlJson: $optionsHtmlJson, ')
          ..write('explanationHtml: $explanationHtml, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('lettersJson: $lettersJson, ')
          ..write('passageId: $passageId, ')
          ..write('section: $section, ')
          ..write('year: $year, ')
          ..write('answer: $answer, ')
          ..write('explanation: $explanation, ')
          ..write('mediaJson: $mediaJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VaultPassagesTable extends VaultPassages
    with TableInfo<$VaultPassagesTable, VaultPassage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultPassagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyHtmlMeta = const VerificationMeta(
    'bodyHtml',
  );
  @override
  late final GeneratedColumn<String> bodyHtml = GeneratedColumn<String>(
    'body_html',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, body, bodyHtml];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_passages';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultPassage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('body_html')) {
      context.handle(
        _bodyHtmlMeta,
        bodyHtml.isAcceptableOrUnknown(data['body_html']!, _bodyHtmlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultPassage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultPassage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      bodyHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_html'],
      ),
    );
  }

  @override
  $VaultPassagesTable createAlias(String alias) {
    return $VaultPassagesTable(attachedDatabase, alias);
  }
}

class VaultPassage extends DataClass implements Insertable<VaultPassage> {
  final String id;
  final String title;
  final String body;

  /// Same story as the question: a comprehension passage is the one piece of
  /// content most likely to carry italics and paragraph breaks, and offline
  /// it was arriving as one flat block.
  final String? bodyHtml;
  const VaultPassage({
    required this.id,
    required this.title,
    required this.body,
    this.bodyHtml,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || bodyHtml != null) {
      map['body_html'] = Variable<String>(bodyHtml);
    }
    return map;
  }

  VaultPassagesCompanion toCompanion(bool nullToAbsent) {
    return VaultPassagesCompanion(
      id: Value(id),
      title: Value(title),
      body: Value(body),
      bodyHtml: bodyHtml == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyHtml),
    );
  }

  factory VaultPassage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultPassage(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      bodyHtml: serializer.fromJson<String?>(json['bodyHtml']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'bodyHtml': serializer.toJson<String?>(bodyHtml),
    };
  }

  VaultPassage copyWith({
    String? id,
    String? title,
    String? body,
    Value<String?> bodyHtml = const Value.absent(),
  }) => VaultPassage(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    bodyHtml: bodyHtml.present ? bodyHtml.value : this.bodyHtml,
  );
  VaultPassage copyWithCompanion(VaultPassagesCompanion data) {
    return VaultPassage(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      bodyHtml: data.bodyHtml.present ? data.bodyHtml.value : this.bodyHtml,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultPassage(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('bodyHtml: $bodyHtml')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, body, bodyHtml);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultPassage &&
          other.id == this.id &&
          other.title == this.title &&
          other.body == this.body &&
          other.bodyHtml == this.bodyHtml);
}

class VaultPassagesCompanion extends UpdateCompanion<VaultPassage> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> body;
  final Value<String?> bodyHtml;
  final Value<int> rowid;
  const VaultPassagesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.bodyHtml = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultPassagesCompanion.insert({
    required String id,
    required String title,
    required String body,
    this.bodyHtml = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       body = Value(body);
  static Insertable<VaultPassage> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? bodyHtml,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (bodyHtml != null) 'body_html': bodyHtml,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultPassagesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? body,
    Value<String?>? bodyHtml,
    Value<int>? rowid,
  }) {
    return VaultPassagesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      bodyHtml: bodyHtml ?? this.bodyHtml,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (bodyHtml.present) {
      map['body_html'] = Variable<String>(bodyHtml.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultPassagesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('bodyHtml: $bodyHtml, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VaultMaterialsTable extends VaultMaterials
    with TableInfo<$VaultMaterialsTable, VaultMaterial> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultMaterialsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    subjectId,
    title,
    body,
    path,
    bytes,
    savedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_materials';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultMaterial> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultMaterial map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultMaterial(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      ),
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $VaultMaterialsTable createAlias(String alias) {
    return $VaultMaterialsTable(attachedDatabase, alias);
  }
}

class VaultMaterial extends DataClass implements Insertable<VaultMaterial> {
  final String id;

  /// 'note' | 'document'
  final String kind;
  final String subjectId;
  final String title;

  /// The note's HTML. Null for a document.
  final String? body;

  /// Where the file was written. Null for a note.
  final String? path;

  /// What it actually cost, so the vault screen can tell a student what
  /// deleting it would give back.
  final int bytes;
  final DateTime savedAt;
  const VaultMaterial({
    required this.id,
    required this.kind,
    required this.subjectId,
    required this.title,
    this.body,
    this.path,
    required this.bytes,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['subject_id'] = Variable<String>(subjectId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || path != null) {
      map['path'] = Variable<String>(path);
    }
    map['bytes'] = Variable<int>(bytes);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  VaultMaterialsCompanion toCompanion(bool nullToAbsent) {
    return VaultMaterialsCompanion(
      id: Value(id),
      kind: Value(kind),
      subjectId: Value(subjectId),
      title: Value(title),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      path: path == null && nullToAbsent ? const Value.absent() : Value(path),
      bytes: Value(bytes),
      savedAt: Value(savedAt),
    );
  }

  factory VaultMaterial.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultMaterial(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String?>(json['body']),
      path: serializer.fromJson<String?>(json['path']),
      bytes: serializer.fromJson<int>(json['bytes']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'subjectId': serializer.toJson<String>(subjectId),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String?>(body),
      'path': serializer.toJson<String?>(path),
      'bytes': serializer.toJson<int>(bytes),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  VaultMaterial copyWith({
    String? id,
    String? kind,
    String? subjectId,
    String? title,
    Value<String?> body = const Value.absent(),
    Value<String?> path = const Value.absent(),
    int? bytes,
    DateTime? savedAt,
  }) => VaultMaterial(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    subjectId: subjectId ?? this.subjectId,
    title: title ?? this.title,
    body: body.present ? body.value : this.body,
    path: path.present ? path.value : this.path,
    bytes: bytes ?? this.bytes,
    savedAt: savedAt ?? this.savedAt,
  );
  VaultMaterial copyWithCompanion(VaultMaterialsCompanion data) {
    return VaultMaterial(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      path: data.path.present ? data.path.value : this.path,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultMaterial(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('subjectId: $subjectId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('path: $path, ')
          ..write('bytes: $bytes, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, subjectId, title, body, path, bytes, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultMaterial &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.subjectId == this.subjectId &&
          other.title == this.title &&
          other.body == this.body &&
          other.path == this.path &&
          other.bytes == this.bytes &&
          other.savedAt == this.savedAt);
}

class VaultMaterialsCompanion extends UpdateCompanion<VaultMaterial> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> subjectId;
  final Value<String> title;
  final Value<String?> body;
  final Value<String?> path;
  final Value<int> bytes;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const VaultMaterialsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.path = const Value.absent(),
    this.bytes = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultMaterialsCompanion.insert({
    required String id,
    required String kind,
    required String subjectId,
    required String title,
    this.body = const Value.absent(),
    this.path = const Value.absent(),
    this.bytes = const Value.absent(),
    required DateTime savedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       subjectId = Value(subjectId),
       title = Value(title),
       savedAt = Value(savedAt);
  static Insertable<VaultMaterial> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? subjectId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? path,
    Expression<int>? bytes,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (subjectId != null) 'subject_id': subjectId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (path != null) 'path': path,
      if (bytes != null) 'bytes': bytes,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultMaterialsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? subjectId,
    Value<String>? title,
    Value<String?>? body,
    Value<String?>? path,
    Value<int>? bytes,
    Value<DateTime>? savedAt,
    Value<int>? rowid,
  }) {
    return VaultMaterialsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      body: body ?? this.body,
      path: path ?? this.path,
      bytes: bytes ?? this.bytes,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultMaterialsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('subjectId: $subjectId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('path: $path, ')
          ..write('bytes: $bytes, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingResultsTable extends PendingResults
    with TableInfo<$PendingResultsTable, PendingResult> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _examIdMeta = const VerificationMeta('examId');
  @override
  late final GeneratedColumn<String> examId = GeneratedColumn<String>(
    'exam_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<int> correct = GeneratedColumn<int>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answersJsonMeta = const VerificationMeta(
    'answersJson',
  );
  @override
  late final GeneratedColumn<String> answersJson = GeneratedColumn<String>(
    'answers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<DateTime> takenAt = GeneratedColumn<DateTime>(
    'taken_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    subjectId,
    examId,
    correct,
    total,
    durationSeconds,
    answersJson,
    takenAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingResult> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('exam_id')) {
      context.handle(
        _examIdMeta,
        examId.isAcceptableOrUnknown(data['exam_id']!, _examIdMeta),
      );
    } else if (isInserting) {
      context.missing(_examIdMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    } else if (isInserting) {
      context.missing(_correctMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('answers_json')) {
      context.handle(
        _answersJsonMeta,
        answersJson.isAcceptableOrUnknown(
          data['answers_json']!,
          _answersJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_answersJsonMeta);
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    } else if (isInserting) {
      context.missing(_takenAtMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  PendingResult map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingResult(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      examId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exam_id'],
      )!,
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      answersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answers_json'],
      )!,
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}taken_at'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $PendingResultsTable createAlias(String alias) {
    return $PendingResultsTable(attachedDatabase, alias);
  }
}

class PendingResult extends DataClass implements Insertable<PendingResult> {
  final String localId;
  final String subjectId;
  final String examId;
  final int correct;
  final int total;
  final int durationSeconds;

  /// questionId -> chosen letter.
  final String answersJson;
  final DateTime takenAt;

  /// Set once the server has accepted it. Kept rather than deleted so a
  /// student can still see the paper they sat in a tunnel.
  final bool synced;
  const PendingResult({
    required this.localId,
    required this.subjectId,
    required this.examId,
    required this.correct,
    required this.total,
    required this.durationSeconds,
    required this.answersJson,
    required this.takenAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    map['subject_id'] = Variable<String>(subjectId);
    map['exam_id'] = Variable<String>(examId);
    map['correct'] = Variable<int>(correct);
    map['total'] = Variable<int>(total);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['answers_json'] = Variable<String>(answersJson);
    map['taken_at'] = Variable<DateTime>(takenAt);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  PendingResultsCompanion toCompanion(bool nullToAbsent) {
    return PendingResultsCompanion(
      localId: Value(localId),
      subjectId: Value(subjectId),
      examId: Value(examId),
      correct: Value(correct),
      total: Value(total),
      durationSeconds: Value(durationSeconds),
      answersJson: Value(answersJson),
      takenAt: Value(takenAt),
      synced: Value(synced),
    );
  }

  factory PendingResult.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingResult(
      localId: serializer.fromJson<String>(json['localId']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      examId: serializer.fromJson<String>(json['examId']),
      correct: serializer.fromJson<int>(json['correct']),
      total: serializer.fromJson<int>(json['total']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      answersJson: serializer.fromJson<String>(json['answersJson']),
      takenAt: serializer.fromJson<DateTime>(json['takenAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'subjectId': serializer.toJson<String>(subjectId),
      'examId': serializer.toJson<String>(examId),
      'correct': serializer.toJson<int>(correct),
      'total': serializer.toJson<int>(total),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'answersJson': serializer.toJson<String>(answersJson),
      'takenAt': serializer.toJson<DateTime>(takenAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  PendingResult copyWith({
    String? localId,
    String? subjectId,
    String? examId,
    int? correct,
    int? total,
    int? durationSeconds,
    String? answersJson,
    DateTime? takenAt,
    bool? synced,
  }) => PendingResult(
    localId: localId ?? this.localId,
    subjectId: subjectId ?? this.subjectId,
    examId: examId ?? this.examId,
    correct: correct ?? this.correct,
    total: total ?? this.total,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    answersJson: answersJson ?? this.answersJson,
    takenAt: takenAt ?? this.takenAt,
    synced: synced ?? this.synced,
  );
  PendingResult copyWithCompanion(PendingResultsCompanion data) {
    return PendingResult(
      localId: data.localId.present ? data.localId.value : this.localId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      examId: data.examId.present ? data.examId.value : this.examId,
      correct: data.correct.present ? data.correct.value : this.correct,
      total: data.total.present ? data.total.value : this.total,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      answersJson: data.answersJson.present
          ? data.answersJson.value
          : this.answersJson,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingResult(')
          ..write('localId: $localId, ')
          ..write('subjectId: $subjectId, ')
          ..write('examId: $examId, ')
          ..write('correct: $correct, ')
          ..write('total: $total, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('answersJson: $answersJson, ')
          ..write('takenAt: $takenAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    subjectId,
    examId,
    correct,
    total,
    durationSeconds,
    answersJson,
    takenAt,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingResult &&
          other.localId == this.localId &&
          other.subjectId == this.subjectId &&
          other.examId == this.examId &&
          other.correct == this.correct &&
          other.total == this.total &&
          other.durationSeconds == this.durationSeconds &&
          other.answersJson == this.answersJson &&
          other.takenAt == this.takenAt &&
          other.synced == this.synced);
}

class PendingResultsCompanion extends UpdateCompanion<PendingResult> {
  final Value<String> localId;
  final Value<String> subjectId;
  final Value<String> examId;
  final Value<int> correct;
  final Value<int> total;
  final Value<int> durationSeconds;
  final Value<String> answersJson;
  final Value<DateTime> takenAt;
  final Value<bool> synced;
  final Value<int> rowid;
  const PendingResultsCompanion({
    this.localId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.examId = const Value.absent(),
    this.correct = const Value.absent(),
    this.total = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.answersJson = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingResultsCompanion.insert({
    required String localId,
    required String subjectId,
    required String examId,
    required int correct,
    required int total,
    required int durationSeconds,
    required String answersJson,
    required DateTime takenAt,
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       subjectId = Value(subjectId),
       examId = Value(examId),
       correct = Value(correct),
       total = Value(total),
       durationSeconds = Value(durationSeconds),
       answersJson = Value(answersJson),
       takenAt = Value(takenAt);
  static Insertable<PendingResult> custom({
    Expression<String>? localId,
    Expression<String>? subjectId,
    Expression<String>? examId,
    Expression<int>? correct,
    Expression<int>? total,
    Expression<int>? durationSeconds,
    Expression<String>? answersJson,
    Expression<DateTime>? takenAt,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (subjectId != null) 'subject_id': subjectId,
      if (examId != null) 'exam_id': examId,
      if (correct != null) 'correct': correct,
      if (total != null) 'total': total,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (answersJson != null) 'answers_json': answersJson,
      if (takenAt != null) 'taken_at': takenAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingResultsCompanion copyWith({
    Value<String>? localId,
    Value<String>? subjectId,
    Value<String>? examId,
    Value<int>? correct,
    Value<int>? total,
    Value<int>? durationSeconds,
    Value<String>? answersJson,
    Value<DateTime>? takenAt,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return PendingResultsCompanion(
      localId: localId ?? this.localId,
      subjectId: subjectId ?? this.subjectId,
      examId: examId ?? this.examId,
      correct: correct ?? this.correct,
      total: total ?? this.total,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      answersJson: answersJson ?? this.answersJson,
      takenAt: takenAt ?? this.takenAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (examId.present) {
      map['exam_id'] = Variable<String>(examId.value);
    }
    if (correct.present) {
      map['correct'] = Variable<int>(correct.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (answersJson.present) {
      map['answers_json'] = Variable<String>(answersJson.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<DateTime>(takenAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingResultsCompanion(')
          ..write('localId: $localId, ')
          ..write('subjectId: $subjectId, ')
          ..write('examId: $examId, ')
          ..write('correct: $correct, ')
          ..write('total: $total, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('answersJson: $answersJson, ')
          ..write('takenAt: $takenAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$VaultDb extends GeneratedDatabase {
  _$VaultDb(QueryExecutor e) : super(e);
  $VaultDbManager get managers => $VaultDbManager(this);
  late final $PacksTable packs = $PacksTable(this);
  late final $VaultQuestionsTable vaultQuestions = $VaultQuestionsTable(this);
  late final $VaultPassagesTable vaultPassages = $VaultPassagesTable(this);
  late final $VaultMaterialsTable vaultMaterials = $VaultMaterialsTable(this);
  late final $PendingResultsTable pendingResults = $PendingResultsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    packs,
    vaultQuestions,
    vaultPassages,
    vaultMaterials,
    pendingResults,
  ];
}

typedef $$PacksTableCreateCompanionBuilder = PacksCompanion Function({
  required String subjectId,
  required String subjectName,
  required String examId,
  required String examSlug,
  required String examShort,
  required int count,
  required DateTime downloadedAt,
  Value<int> rowid,
});
typedef $$PacksTableUpdateCompanionBuilder = PacksCompanion Function({
  Value<String> subjectId,
  Value<String> subjectName,
  Value<String> examId,
  Value<String> examSlug,
  Value<String> examShort,
  Value<int> count,
  Value<DateTime> downloadedAt,
  Value<int> rowid,
});

class $$PacksTableFilterComposer extends Composer<_$VaultDb, $PacksTable> {
  $$PacksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get examId => $composableBuilder(
    column: $table.examId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get examSlug => $composableBuilder(
    column: $table.examSlug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get examShort => $composableBuilder(
    column: $table.examShort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PacksTableOrderingComposer extends Composer<_$VaultDb, $PacksTable> {
  $$PacksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examId => $composableBuilder(
    column: $table.examId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examSlug => $composableBuilder(
    column: $table.examSlug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examShort => $composableBuilder(
    column: $table.examShort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PacksTableAnnotationComposer extends Composer<_$VaultDb, $PacksTable> {
  $$PacksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get examId =>
      $composableBuilder(column: $table.examId, builder: (column) => column);

  GeneratedColumn<String> get examSlug =>
      $composableBuilder(column: $table.examSlug, builder: (column) => column);

  GeneratedColumn<String> get examShort =>
      $composableBuilder(column: $table.examShort, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );
}

class $$PacksTableTableManager
    extends
        RootTableManager<
          _$VaultDb,
          $PacksTable,
          Pack,
          $$PacksTableFilterComposer,
          $$PacksTableOrderingComposer,
          $$PacksTableAnnotationComposer,
          $$PacksTableCreateCompanionBuilder,
          $$PacksTableUpdateCompanionBuilder,
          (Pack, BaseReferences<_$VaultDb, $PacksTable, Pack>),
          Pack,
          PrefetchHooks Function()
        > {
  $$PacksTableTableManager(_$VaultDb db, $PacksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PacksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PacksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PacksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> subjectId = const Value.absent(),
                Value<String> subjectName = const Value.absent(),
                Value<String> examId = const Value.absent(),
                Value<String> examSlug = const Value.absent(),
                Value<String> examShort = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<DateTime> downloadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PacksCompanion(
                subjectId: subjectId,
                subjectName: subjectName,
                examId: examId,
                examSlug: examSlug,
                examShort: examShort,
                count: count,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String subjectId,
                required String subjectName,
                required String examId,
                required String examSlug,
                required String examShort,
                required int count,
                required DateTime downloadedAt,
                Value<int> rowid = const Value.absent(),
              }) => PacksCompanion.insert(
                subjectId: subjectId,
                subjectName: subjectName,
                examId: examId,
                examSlug: examSlug,
                examShort: examShort,
                count: count,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PacksTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDb,
      $PacksTable,
      Pack,
      $$PacksTableFilterComposer,
      $$PacksTableOrderingComposer,
      $$PacksTableAnnotationComposer,
      $$PacksTableCreateCompanionBuilder,
      $$PacksTableUpdateCompanionBuilder,
      (Pack, BaseReferences<_$VaultDb, $PacksTable, Pack>),
      Pack,
      PrefetchHooks Function()
    >;
typedef $$VaultQuestionsTableCreateCompanionBuilder =
    VaultQuestionsCompanion Function({
      required String id,
      required String subjectId,
      required String question,
      Value<String?> questionHtml,
      Value<String?> optionsHtmlJson,
      Value<String?> explanationHtml,
      required String optionsJson,
      required String lettersJson,
      Value<String?> passageId,
      Value<String?> section,
      Value<int?> year,
      Value<String?> answer,
      Value<String?> explanation,
      Value<String?> mediaJson,
      Value<int> rowid,
    });
typedef $$VaultQuestionsTableUpdateCompanionBuilder =
    VaultQuestionsCompanion Function({
      Value<String> id,
      Value<String> subjectId,
      Value<String> question,
      Value<String?> questionHtml,
      Value<String?> optionsHtmlJson,
      Value<String?> explanationHtml,
      Value<String> optionsJson,
      Value<String> lettersJson,
      Value<String?> passageId,
      Value<String?> section,
      Value<int?> year,
      Value<String?> answer,
      Value<String?> explanation,
      Value<String?> mediaJson,
      Value<int> rowid,
    });

class $$VaultQuestionsTableFilterComposer
    extends Composer<_$VaultDb, $VaultQuestionsTable> {
  $$VaultQuestionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionHtml => $composableBuilder(
    column: $table.questionHtml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionsHtmlJson => $composableBuilder(
    column: $table.optionsHtmlJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explanationHtml => $composableBuilder(
    column: $table.explanationHtml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lettersJson => $composableBuilder(
    column: $table.lettersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passageId => $composableBuilder(
    column: $table.passageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaJson => $composableBuilder(
    column: $table.mediaJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultQuestionsTableOrderingComposer
    extends Composer<_$VaultDb, $VaultQuestionsTable> {
  $$VaultQuestionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionHtml => $composableBuilder(
    column: $table.questionHtml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionsHtmlJson => $composableBuilder(
    column: $table.optionsHtmlJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanationHtml => $composableBuilder(
    column: $table.explanationHtml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lettersJson => $composableBuilder(
    column: $table.lettersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passageId => $composableBuilder(
    column: $table.passageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaJson => $composableBuilder(
    column: $table.mediaJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultQuestionsTableAnnotationComposer
    extends Composer<_$VaultDb, $VaultQuestionsTable> {
  $$VaultQuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get questionHtml => $composableBuilder(
    column: $table.questionHtml,
    builder: (column) => column,
  );

  GeneratedColumn<String> get optionsHtmlJson => $composableBuilder(
    column: $table.optionsHtmlJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get explanationHtml => $composableBuilder(
    column: $table.explanationHtml,
    builder: (column) => column,
  );

  GeneratedColumn<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lettersJson => $composableBuilder(
    column: $table.lettersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get passageId =>
      $composableBuilder(column: $table.passageId, builder: (column) => column);

  GeneratedColumn<String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaJson =>
      $composableBuilder(column: $table.mediaJson, builder: (column) => column);
}

class $$VaultQuestionsTableTableManager
    extends
        RootTableManager<
          _$VaultDb,
          $VaultQuestionsTable,
          VaultQuestion,
          $$VaultQuestionsTableFilterComposer,
          $$VaultQuestionsTableOrderingComposer,
          $$VaultQuestionsTableAnnotationComposer,
          $$VaultQuestionsTableCreateCompanionBuilder,
          $$VaultQuestionsTableUpdateCompanionBuilder,
          (
            VaultQuestion,
            BaseReferences<_$VaultDb, $VaultQuestionsTable, VaultQuestion>,
          ),
          VaultQuestion,
          PrefetchHooks Function()
        > {
  $$VaultQuestionsTableTableManager(_$VaultDb db, $VaultQuestionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultQuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultQuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultQuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String?> questionHtml = const Value.absent(),
                Value<String?> optionsHtmlJson = const Value.absent(),
                Value<String?> explanationHtml = const Value.absent(),
                Value<String> optionsJson = const Value.absent(),
                Value<String> lettersJson = const Value.absent(),
                Value<String?> passageId = const Value.absent(),
                Value<String?> section = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> answer = const Value.absent(),
                Value<String?> explanation = const Value.absent(),
                Value<String?> mediaJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultQuestionsCompanion(
                id: id,
                subjectId: subjectId,
                question: question,
                questionHtml: questionHtml,
                optionsHtmlJson: optionsHtmlJson,
                explanationHtml: explanationHtml,
                optionsJson: optionsJson,
                lettersJson: lettersJson,
                passageId: passageId,
                section: section,
                year: year,
                answer: answer,
                explanation: explanation,
                mediaJson: mediaJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String subjectId,
                required String question,
                Value<String?> questionHtml = const Value.absent(),
                Value<String?> optionsHtmlJson = const Value.absent(),
                Value<String?> explanationHtml = const Value.absent(),
                required String optionsJson,
                required String lettersJson,
                Value<String?> passageId = const Value.absent(),
                Value<String?> section = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> answer = const Value.absent(),
                Value<String?> explanation = const Value.absent(),
                Value<String?> mediaJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultQuestionsCompanion.insert(
                id: id,
                subjectId: subjectId,
                question: question,
                questionHtml: questionHtml,
                optionsHtmlJson: optionsHtmlJson,
                explanationHtml: explanationHtml,
                optionsJson: optionsJson,
                lettersJson: lettersJson,
                passageId: passageId,
                section: section,
                year: year,
                answer: answer,
                explanation: explanation,
                mediaJson: mediaJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultQuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDb,
      $VaultQuestionsTable,
      VaultQuestion,
      $$VaultQuestionsTableFilterComposer,
      $$VaultQuestionsTableOrderingComposer,
      $$VaultQuestionsTableAnnotationComposer,
      $$VaultQuestionsTableCreateCompanionBuilder,
      $$VaultQuestionsTableUpdateCompanionBuilder,
      (
        VaultQuestion,
        BaseReferences<_$VaultDb, $VaultQuestionsTable, VaultQuestion>,
      ),
      VaultQuestion,
      PrefetchHooks Function()
    >;
typedef $$VaultPassagesTableCreateCompanionBuilder =
    VaultPassagesCompanion Function({
      required String id,
      required String title,
      required String body,
      Value<String?> bodyHtml,
      Value<int> rowid,
    });
typedef $$VaultPassagesTableUpdateCompanionBuilder =
    VaultPassagesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> body,
      Value<String?> bodyHtml,
      Value<int> rowid,
    });

class $$VaultPassagesTableFilterComposer
    extends Composer<_$VaultDb, $VaultPassagesTable> {
  $$VaultPassagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyHtml => $composableBuilder(
    column: $table.bodyHtml,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultPassagesTableOrderingComposer
    extends Composer<_$VaultDb, $VaultPassagesTable> {
  $$VaultPassagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyHtml => $composableBuilder(
    column: $table.bodyHtml,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultPassagesTableAnnotationComposer
    extends Composer<_$VaultDb, $VaultPassagesTable> {
  $$VaultPassagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get bodyHtml =>
      $composableBuilder(column: $table.bodyHtml, builder: (column) => column);
}

class $$VaultPassagesTableTableManager
    extends
        RootTableManager<
          _$VaultDb,
          $VaultPassagesTable,
          VaultPassage,
          $$VaultPassagesTableFilterComposer,
          $$VaultPassagesTableOrderingComposer,
          $$VaultPassagesTableAnnotationComposer,
          $$VaultPassagesTableCreateCompanionBuilder,
          $$VaultPassagesTableUpdateCompanionBuilder,
          (
            VaultPassage,
            BaseReferences<_$VaultDb, $VaultPassagesTable, VaultPassage>,
          ),
          VaultPassage,
          PrefetchHooks Function()
        > {
  $$VaultPassagesTableTableManager(_$VaultDb db, $VaultPassagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultPassagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultPassagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultPassagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> bodyHtml = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultPassagesCompanion(
                id: id,
                title: title,
                body: body,
                bodyHtml: bodyHtml,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String body,
                Value<String?> bodyHtml = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultPassagesCompanion.insert(
                id: id,
                title: title,
                body: body,
                bodyHtml: bodyHtml,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultPassagesTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDb,
      $VaultPassagesTable,
      VaultPassage,
      $$VaultPassagesTableFilterComposer,
      $$VaultPassagesTableOrderingComposer,
      $$VaultPassagesTableAnnotationComposer,
      $$VaultPassagesTableCreateCompanionBuilder,
      $$VaultPassagesTableUpdateCompanionBuilder,
      (
        VaultPassage,
        BaseReferences<_$VaultDb, $VaultPassagesTable, VaultPassage>,
      ),
      VaultPassage,
      PrefetchHooks Function()
    >;
typedef $$VaultMaterialsTableCreateCompanionBuilder =
    VaultMaterialsCompanion Function({
      required String id,
      required String kind,
      required String subjectId,
      required String title,
      Value<String?> body,
      Value<String?> path,
      Value<int> bytes,
      required DateTime savedAt,
      Value<int> rowid,
    });
typedef $$VaultMaterialsTableUpdateCompanionBuilder =
    VaultMaterialsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> subjectId,
      Value<String> title,
      Value<String?> body,
      Value<String?> path,
      Value<int> bytes,
      Value<DateTime> savedAt,
      Value<int> rowid,
    });

class $$VaultMaterialsTableFilterComposer
    extends Composer<_$VaultDb, $VaultMaterialsTable> {
  $$VaultMaterialsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultMaterialsTableOrderingComposer
    extends Composer<_$VaultDb, $VaultMaterialsTable> {
  $$VaultMaterialsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultMaterialsTableAnnotationComposer
    extends Composer<_$VaultDb, $VaultMaterialsTable> {
  $$VaultMaterialsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$VaultMaterialsTableTableManager
    extends
        RootTableManager<
          _$VaultDb,
          $VaultMaterialsTable,
          VaultMaterial,
          $$VaultMaterialsTableFilterComposer,
          $$VaultMaterialsTableOrderingComposer,
          $$VaultMaterialsTableAnnotationComposer,
          $$VaultMaterialsTableCreateCompanionBuilder,
          $$VaultMaterialsTableUpdateCompanionBuilder,
          (
            VaultMaterial,
            BaseReferences<_$VaultDb, $VaultMaterialsTable, VaultMaterial>,
          ),
          VaultMaterial,
          PrefetchHooks Function()
        > {
  $$VaultMaterialsTableTableManager(_$VaultDb db, $VaultMaterialsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultMaterialsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultMaterialsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultMaterialsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultMaterialsCompanion(
                id: id,
                kind: kind,
                subjectId: subjectId,
                title: title,
                body: body,
                path: path,
                bytes: bytes,
                savedAt: savedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String subjectId,
                required String title,
                Value<String?> body = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                required DateTime savedAt,
                Value<int> rowid = const Value.absent(),
              }) => VaultMaterialsCompanion.insert(
                id: id,
                kind: kind,
                subjectId: subjectId,
                title: title,
                body: body,
                path: path,
                bytes: bytes,
                savedAt: savedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultMaterialsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDb,
      $VaultMaterialsTable,
      VaultMaterial,
      $$VaultMaterialsTableFilterComposer,
      $$VaultMaterialsTableOrderingComposer,
      $$VaultMaterialsTableAnnotationComposer,
      $$VaultMaterialsTableCreateCompanionBuilder,
      $$VaultMaterialsTableUpdateCompanionBuilder,
      (
        VaultMaterial,
        BaseReferences<_$VaultDb, $VaultMaterialsTable, VaultMaterial>,
      ),
      VaultMaterial,
      PrefetchHooks Function()
    >;
typedef $$PendingResultsTableCreateCompanionBuilder =
    PendingResultsCompanion Function({
      required String localId,
      required String subjectId,
      required String examId,
      required int correct,
      required int total,
      required int durationSeconds,
      required String answersJson,
      required DateTime takenAt,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$PendingResultsTableUpdateCompanionBuilder =
    PendingResultsCompanion Function({
      Value<String> localId,
      Value<String> subjectId,
      Value<String> examId,
      Value<int> correct,
      Value<int> total,
      Value<int> durationSeconds,
      Value<String> answersJson,
      Value<DateTime> takenAt,
      Value<bool> synced,
      Value<int> rowid,
    });

class $$PendingResultsTableFilterComposer
    extends Composer<_$VaultDb, $PendingResultsTable> {
  $$PendingResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get examId => $composableBuilder(
    column: $table.examId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingResultsTableOrderingComposer
    extends Composer<_$VaultDb, $PendingResultsTable> {
  $$PendingResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examId => $composableBuilder(
    column: $table.examId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingResultsTableAnnotationComposer
    extends Composer<_$VaultDb, $PendingResultsTable> {
  $$PendingResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get examId =>
      $composableBuilder(column: $table.examId, builder: (column) => column);

  GeneratedColumn<int> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$PendingResultsTableTableManager
    extends
        RootTableManager<
          _$VaultDb,
          $PendingResultsTable,
          PendingResult,
          $$PendingResultsTableFilterComposer,
          $$PendingResultsTableOrderingComposer,
          $$PendingResultsTableAnnotationComposer,
          $$PendingResultsTableCreateCompanionBuilder,
          $$PendingResultsTableUpdateCompanionBuilder,
          (
            PendingResult,
            BaseReferences<_$VaultDb, $PendingResultsTable, PendingResult>,
          ),
          PendingResult,
          PrefetchHooks Function()
        > {
  $$PendingResultsTableTableManager(_$VaultDb db, $PendingResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> examId = const Value.absent(),
                Value<int> correct = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<String> answersJson = const Value.absent(),
                Value<DateTime> takenAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingResultsCompanion(
                localId: localId,
                subjectId: subjectId,
                examId: examId,
                correct: correct,
                total: total,
                durationSeconds: durationSeconds,
                answersJson: answersJson,
                takenAt: takenAt,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                required String subjectId,
                required String examId,
                required int correct,
                required int total,
                required int durationSeconds,
                required String answersJson,
                required DateTime takenAt,
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingResultsCompanion.insert(
                localId: localId,
                subjectId: subjectId,
                examId: examId,
                correct: correct,
                total: total,
                durationSeconds: durationSeconds,
                answersJson: answersJson,
                takenAt: takenAt,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultDb,
      $PendingResultsTable,
      PendingResult,
      $$PendingResultsTableFilterComposer,
      $$PendingResultsTableOrderingComposer,
      $$PendingResultsTableAnnotationComposer,
      $$PendingResultsTableCreateCompanionBuilder,
      $$PendingResultsTableUpdateCompanionBuilder,
      (
        PendingResult,
        BaseReferences<_$VaultDb, $PendingResultsTable, PendingResult>,
      ),
      PendingResult,
      PrefetchHooks Function()
    >;

class $VaultDbManager {
  final _$VaultDb _db;
  $VaultDbManager(this._db);
  $$PacksTableTableManager get packs =>
      $$PacksTableTableManager(_db, _db.packs);
  $$VaultQuestionsTableTableManager get vaultQuestions =>
      $$VaultQuestionsTableTableManager(_db, _db.vaultQuestions);
  $$VaultPassagesTableTableManager get vaultPassages =>
      $$VaultPassagesTableTableManager(_db, _db.vaultPassages);
  $$VaultMaterialsTableTableManager get vaultMaterials =>
      $$VaultMaterialsTableTableManager(_db, _db.vaultMaterials);
  $$PendingResultsTableTableManager get pendingResults =>
      $$PendingResultsTableTableManager(_db, _db.pendingResults);
}
