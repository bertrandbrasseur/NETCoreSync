import 'package:meta/meta.dart';
import 'package:moor/moor.dart';
import 'package:netcoresync_moor/netcoresync_moor.dart';
import 'netcoresync_exceptions.dart';
import 'netcoresync_engine.dart';
import 'netcoresync_classes.dart';
import 'data_access.dart';
import 'client_select.dart';
import 'client_insert.dart';
import 'client_update.dart';
import 'client_delete.dart';
import 'sync_handler.dart';
import 'sync_session.dart';

mixin NetCoreSyncClient on GeneratedDatabase {
  DataAccess? _dataAccess;

  bool get netCoreSyncInitialized => _dataAccess != null;

  @internal
  DataAccess get dataAccess {
    if (!netCoreSyncInitialized) throw NetCoreSyncNotInitializedException();
    return _dataAccess!;
  }

  Future<void> netCoreSyncInitializeClient(
    NetCoreSyncEngine engine,
  ) async {
    _dataAccess = DataAccess(
      this,
      engine,
    );
  }

  dynamic get netCoreSyncResolvedEngine => dataAccess.resolvedEngine;

  SyncIdInfo? netCoreSyncGetSyncIdInfo() => dataAccess.syncIdInfo;

  void netCoreSyncSetSyncIdInfo(SyncIdInfo value) {
    if (!netCoreSyncInitialized) throw NetCoreSyncNotInitializedException();
    if (value.syncId.isEmpty) {
      throw NetCoreSyncException("SyncIdInfo.syncId cannot be empty");
    }
    if (value.linkedSyncIds.isNotEmpty && value.linkedSyncIds.contains("")) {
      throw NetCoreSyncException(
          "SyncIdInfo.linkedSyncIds should not contain empty string");
    }
    if (value.linkedSyncIds.isNotEmpty &&
        value.linkedSyncIds.contains(value.syncId)) {
      throw NetCoreSyncException(
          "SyncIdInfo.linkedSyncIds cannot contain the syncId itself");
    }
    dataAccess.syncIdInfo = value;
    dataAccess.activeSyncId = dataAccess.syncIdInfo!.syncId;
  }

  String? netCoreSyncGetActiveSyncId() => dataAccess.activeSyncId;

  void netCoreSyncSetActiveSyncId(String value) {
    if (!netCoreSyncInitialized) throw NetCoreSyncNotInitializedException();
    if (dataAccess.syncIdInfo == null) {
      throw NetCoreSyncSyncIdInfoNotSetException();
    }
    if (value.isEmpty) {
      throw NetCoreSyncException("The active syncId cannot be empty");
    }
    if (dataAccess.syncIdInfo!.syncId != value &&
        !dataAccess.syncIdInfo!.linkedSyncIds.contains(value)) {
      throw NetCoreSyncException(
          "The active syncId is different than the SyncIdInfo.syncId and also "
          "cannot be found in the SyncIdInfo.linkedSyncIds");
    }
    dataAccess.activeSyncId = value;
  }

  String netCoreSyncAllSyncIds() {
    return dataAccess.syncIdInfo?.allSyncIds ?? "";
  }

  Future<SyncResult> netCoreSyncSynchronize({
    required String url,
    SyncEvent? syncEvent,
    Map<String, dynamic> customInfo = const {},
  }) async {
    if (!netCoreSyncInitialized) throw NetCoreSyncNotInitializedException();
    if (dataAccess.syncIdInfo == null) {
      throw NetCoreSyncSyncIdInfoNotSetException();
    }
    if (dataAccess.inTransaction()) {
      throw NetCoreSyncMustNotInsideTransactionException();
    }

    SyncSession syncSession = SyncSession(
      syncHandler: SyncHandler(
        url: url,
      ),
      dataAccess: dataAccess,
      syncEvent: syncEvent,
      customInfo: customInfo,
    );

    return syncSession.synchronize();
  }

  SyncSimpleSelectStatement<T, R> syncSelect<T extends HasResultSet, R>(
    SyncBaseTable<T, R> table, {
    bool distinct = false,
  }) {
    if (!netCoreSyncInitialized) throw NetCoreSyncNotInitializedException();
    return SyncSimpleSelectStatement(
      dataAccess,
      table as ResultSetImplementation<T, R>,
      distinct: distinct,
    );
  }

  SyncJoinedSelectStatement<T, R> syncSelectOnly<T extends HasResultSet, R>(
    SyncBaseTable<T, R> table, {
    bool distinct = false,
  }) {
    if (!netCoreSyncInitialized) throw NetCoreSyncNotInitializedException();
    return SyncJoinedSelectStatement<T, R>(
      dataAccess,
      table as ResultSetImplementation<T, R>,
      [],
      distinct,
      false,
    );
  }

  SyncInsertStatement<T, D> syncInto<T extends Table, D>(
    TableInfo<T, D> table,
  ) {
    if (!netCoreSyncInitialized) throw NetCoreSyncNotInitializedException();
    return SyncInsertStatement<T, D>(
      dataAccess,
      table,
    );
  }

  SyncUpdateStatement<T, D> syncUpdate<T extends Table, D>(
    TableInfo<T, D> table,
  ) {
    if (!netCoreSyncInitialized) throw NetCoreSyncNotInitializedException();
    return SyncUpdateStatement<T, D>(
      dataAccess,
      table,
    );
  }

  SyncDeleteStatement<T, D> syncDelete<T extends Table, D>(
    TableInfo<T, D> table,
  ) {
    if (!netCoreSyncInitialized) throw NetCoreSyncNotInitializedException();
    return SyncDeleteStatement<T, D>(
      dataAccess,
      table,
    );
  }
}
