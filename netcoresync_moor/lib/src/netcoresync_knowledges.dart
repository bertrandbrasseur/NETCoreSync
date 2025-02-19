import 'package:moor/moor.dart';
import 'package:uuid/uuid.dart';

/// The table class used by the framework to keep track of the server's
/// timestamp.
///
/// This table class should be included in the `@UseMoor`'s `tables` list. For
/// example:
/// ```dart
/// @UseMoor(
///   tables: [
///     // ...some table classes here...
///     NetCoreSyncKnowledges,
///   ],
/// )
/// class Database extends _$Database
///     with NetCoreSyncClient, NetCoreSyncClientUser {
/// // ... class code here ...
/// }
/// ```
/// After it is included, no further action is necessary, the framework will
/// utilize it as needed.
@UseRowClass(NetCoreSyncKnowledge, constructor: "fromDb")
class NetCoreSyncKnowledges extends Table {
  TextColumn get id => text().withLength(max: 36)();
  TextColumn get syncId => text().withLength(max: 36)();
  BoolColumn get local => boolean()();
  IntColumn get lastTimeStamp => integer()();
  TextColumn get meta => text()();

  @override
  Set<Column> get primaryKey => {
        id,
        syncId,
      };

  @override
  String? get tableName => "netcoresync_knowledges";
}

/// The Moor's Row Class for [NetCoreSyncKnowledges] table.
///
/// *(This class is used internally, no need to use it directly)*
class NetCoreSyncKnowledge implements Insertable<NetCoreSyncKnowledge> {
  String id = Uuid().v4();
  String syncId = "";
  bool local = false;
  int lastTimeStamp = 0;
  String meta = "";

  NetCoreSyncKnowledge();

  NetCoreSyncKnowledge.fromDb({
    required this.id,
    required this.syncId,
    required this.local,
    required this.lastTimeStamp,
    required this.meta,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sync_id'] = Variable<String>(syncId);
    map['local'] = Variable<bool>(local);
    map['last_time_stamp'] = Variable<int>(lastTimeStamp);
    map['meta'] = Variable<String>(meta);
    return map;
  }

  factory NetCoreSyncKnowledge.fromJson(Map<String, dynamic> json) {
    final serializer = moorRuntimeOptions.defaultSerializer;
    NetCoreSyncKnowledge data = NetCoreSyncKnowledge();
    data.id = serializer.fromJson<String>(json['id']);
    data.syncId = serializer.fromJson<String>(json['syncId']);
    data.local = serializer.fromJson<bool>(json['local']);
    data.lastTimeStamp = serializer.fromJson<int>(json['lastTimeStamp']);
    data.meta = serializer.fromJson<String>(json['meta']);
    return data;
  }

  Map<String, dynamic> toJson() {
    final serializer = moorRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'syncId': serializer.toJson<String>(syncId),
      'local': serializer.toJson<bool>(local),
      'lastTimeStamp': serializer.toJson<int>(lastTimeStamp),
      'meta': serializer.toJson<String>(meta),
    };
  }
}
