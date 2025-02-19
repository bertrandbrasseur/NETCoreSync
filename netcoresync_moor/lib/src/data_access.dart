import 'dart:async';
import 'package:moor/moor.dart';
import 'netcoresync_engine.dart';
import 'netcoresync_classes.dart';
import 'netcoresync_knowledges.dart';
import 'netcoresync_exceptions.dart';

class DataAccess<G extends GeneratedDatabase> extends DatabaseAccessor<G> {
  late G database;
  late NetCoreSyncEngine engine;
  late _NetCoreSyncKnowledgesTable knowledges;

  SyncIdInfo? syncIdInfo;
  late String activeSyncId;
  void Function(Object? object)? logger;

  DataAccess(
    G generatedDatabase,
    this.engine,
  ) : super(generatedDatabase) {
    database = attachedDatabase;
    knowledges = _NetCoreSyncKnowledgesTable(database);
  }

  bool inTransaction() {
    return Zone.current[#DatabaseConnectionUser]
        .toString()
        .contains("Transaction");
  }

  dynamic get databaseResolvedEngine =>
      Zone.current[#DatabaseConnectionUser] ?? database;

  Future<String> getLocalKnowledgeId() async {
    // Local Knowledge is always obtained from syncIdInfo.syncId (logged in
    // user), not the activeSyncId, this is to ensure the logged in user's local
    // knowledge id is returned when inserting on behalf of linked SyncId (other
    // linked user). When other users logged into this device, then the
    // netCoreSyncSetIdInfo() should also be called first when logging in.
    if (syncIdInfo == null) throw NetCoreSyncSyncIdInfoNotSetException();
    DatabaseConnectionUser activeDb =
        databaseResolvedEngine as DatabaseConnectionUser;
    NetCoreSyncKnowledge? localKnowledge = await (activeDb.select(knowledges)
          ..where((tbl) => tbl.syncId.equals(syncIdInfo!.syncId) & tbl.local))
        .getSingleOrNull();
    if (localKnowledge == null) {
      NetCoreSyncKnowledge newLocalKnowledge = NetCoreSyncKnowledge();
      newLocalKnowledge.syncId = syncIdInfo!.syncId;
      newLocalKnowledge.local = true;
      await activeDb.into(knowledges).insert(newLocalKnowledge);
      localKnowledge = await (activeDb.select(knowledges)
            ..where((tbl) => tbl.id.equals(newLocalKnowledge.id)))
          .getSingle();
    }
    // When the logged in user is inserting on behalf of any linked SyncId, even
    // though the returned knowledgeId is the same as the local's logged in
    // user, it still important to have the combination of linkedSyncId +
    // localKnowledgeId data in the knowledge table. This is to ensure that
    // all known knowledges are sent to the server during sync, and the
    // integrity of syncId + knowledgeId for any row in any table is exist in
    // the knowledge table.
    if (activeSyncId != syncIdInfo!.syncId) {
      NetCoreSyncKnowledge? onBehalfKnowledge =
          await (activeDb.select(knowledges)
                ..where((tbl) =>
                    tbl.syncId.equals(activeSyncId) &
                    tbl.id.equals(localKnowledge!.id)))
              .getSingleOrNull();
      if (onBehalfKnowledge == null) {
        onBehalfKnowledge = NetCoreSyncKnowledge();
        onBehalfKnowledge.id = localKnowledge.id;
        onBehalfKnowledge.syncId = activeSyncId;
        onBehalfKnowledge.local = false;
        await activeDb.into(knowledges).insert(onBehalfKnowledge);
      }
    }
    return localKnowledge.id;
  }

  Insertable<D> syncActionInsert<D>(
    Insertable<D> entity,
    String knowledgeId,
  ) {
    if (!engine.tables.containsKey(D)) {
      throw NetCoreSyncTypeNotRegisteredException(D);
    }
    Insertable<D> syncEntity = engine.updateSyncColumns(
      entity,
      synced: false,
      syncId: activeSyncId,
      knowledgeId: knowledgeId,
      deleted: false,
    );
    return syncEntity;
  }

  Insertable<D> syncActionUpdate<D>(
    Insertable<D> entity,
  ) {
    if (!engine.tables.containsKey(D)) {
      throw NetCoreSyncTypeNotRegisteredException(D);
    }
    Insertable<D> entityForUpdate;
    if (entity is RawValuesInsertable<D>) {
      entity.data.remove(engine.tables[D]!.idEscapedName);
      entity.data.remove(engine.tables[D]!.syncIdEscapedName);
      entity.data.remove(engine.tables[D]!.knowledgeIdEscapedName);
      entity.data.remove(engine.tables[D]!.syncIdEscapedName);
      entity.data.remove(engine.tables[D]!.deletedEscapedName);
      entityForUpdate = entity;
    } else {
      entityForUpdate = engine.toSafeCompanion(entity);
    }
    Insertable<D> syncEntity = engine.updateSyncColumns(
      entityForUpdate,
      synced: false,
    );
    return syncEntity;
  }
}

// The following classes were copied from Moor's generated @UseMoor class (with
// several modifications such as making class names private with
// underscore + removing unused constructors)

class _NetCoreSyncKnowledgesTable extends NetCoreSyncKnowledges
    with TableInfo<_NetCoreSyncKnowledgesTable, NetCoreSyncKnowledge> {
  final GeneratedDatabase _db;
  final String? _alias;
  _NetCoreSyncKnowledgesTable(this._db, [this._alias]);
  final VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String?> id = GeneratedColumn<String?>(
      'id', aliasedName, false,
      additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 36),
      typeName: 'TEXT',
      requiredDuringInsert: true);
  final VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String?> syncId = GeneratedColumn<String?>(
      'sync_id', aliasedName, false,
      additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 36),
      typeName: 'TEXT',
      requiredDuringInsert: true);
  final VerificationMeta _localMeta = const VerificationMeta('local');
  @override
  late final GeneratedColumn<bool?> local = GeneratedColumn<bool?>(
      'local', aliasedName, false,
      typeName: 'INTEGER',
      requiredDuringInsert: true,
      defaultConstraints: 'CHECK (local IN (0, 1))');
  final VerificationMeta _lastTimeStampMeta =
      const VerificationMeta('lastTimeStamp');
  @override
  late final GeneratedColumn<int?> lastTimeStamp = GeneratedColumn<int?>(
      'last_time_stamp', aliasedName, false,
      typeName: 'INTEGER', requiredDuringInsert: true);
  final VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String?> meta = GeneratedColumn<String?>(
      'meta', aliasedName, false,
      typeName: 'TEXT', requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, syncId, local, lastTimeStamp, meta];
  @override
  String get aliasedName => _alias ?? 'netcoresync_knowledges';
  @override
  String get actualTableName => 'netcoresync_knowledges';
  @override
  VerificationContext validateIntegrity(
      Insertable<NetCoreSyncKnowledge> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sync_id')) {
      context.handle(_syncIdMeta,
          syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta));
    } else if (isInserting) {
      context.missing(_syncIdMeta);
    }
    if (data.containsKey('local')) {
      context.handle(
          _localMeta, local.isAcceptableOrUnknown(data['local']!, _localMeta));
    } else if (isInserting) {
      context.missing(_localMeta);
    }
    if (data.containsKey('last_time_stamp')) {
      context.handle(
          _lastTimeStampMeta,
          lastTimeStamp.isAcceptableOrUnknown(
              data['last_time_stamp']!, _lastTimeStampMeta));
    } else if (isInserting) {
      context.missing(_lastTimeStampMeta);
    }
    if (data.containsKey('meta')) {
      context.handle(
          _metaMeta, meta.isAcceptableOrUnknown(data['meta']!, _metaMeta));
    } else if (isInserting) {
      context.missing(_metaMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, syncId};
  @override
  NetCoreSyncKnowledge map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NetCoreSyncKnowledge.fromDb(
      id: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}id'])!,
      syncId: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}sync_id'])!,
      local: const BoolType()
          .mapFromDatabaseResponse(data['${effectivePrefix}local'])!,
      lastTimeStamp: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}last_time_stamp'])!,
      meta: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}meta'])!,
    );
  }

  @override
  _NetCoreSyncKnowledgesTable createAlias(String alias) {
    return _NetCoreSyncKnowledgesTable(_db, alias);
  }
}
