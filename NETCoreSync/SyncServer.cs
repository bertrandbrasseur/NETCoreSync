﻿using System;
using System.Linq;
using System.IO;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace NETCoreSync
{
    public class SyncServer
    {
        private static object serverLock = new object();
        private static Dictionary<string, SyncServerLockObject> serverLockObjects = new Dictionary<string, SyncServerLockObject>();

        private readonly SyncEngine syncEngine;

        public SyncServer(SyncEngine syncEngine)
        {
            this.syncEngine = syncEngine;
        }

        private static JObject JsonDefaultResponse()
        {
            JObject jsonResponse = new JObject();
            jsonResponse["isOK"] = true;
            return jsonResponse;
        }

        public static JObject JsonErrorResponse(string message)
        {
            JObject jsonError = JsonDefaultResponse();
            jsonError["isOK"] = false;
            jsonError["errorMessage"] = message;
            return jsonError;
        }

        public JObject Process(byte[] syncDataBytes)
        {
            if (syncDataBytes == null) throw new NullReferenceException(nameof(syncDataBytes));

            JObject jsonResult = JsonDefaultResponse();

            SyncEngine.ProcessPayloadParameter baseParameter = null;
            if (syncEngine.SyncConfiguration.TimeStampStrategy == SyncConfiguration.TimeStampStrategyEnum.UseGlobalTimeStamp)
            {
                baseParameter = new SyncEngine.ProcessPayloadGlobalTimeStampParameter(syncDataBytes);
            }
            else if (syncEngine.SyncConfiguration.TimeStampStrategy == SyncConfiguration.TimeStampStrategyEnum.UseEachDatabaseInstanceTimeStamp)
            {
                baseParameter = new SyncEngine.ProcessPayloadDatabaseTimeStampParameter(syncDataBytes);
            }
            else
            {
                throw new NotImplementedException(syncEngine.SyncConfiguration.TimeStampStrategy.ToString());
            }

            SyncServerLockObject syncServerLockObject = null;
            bool lockTaken = false;

            try
            {
                lock (serverLock)
                {
                    if (!serverLockObjects.ContainsKey(baseParameter.SynchronizationId))
                    {
                        SyncServerLockObject newLockObject = new SyncServerLockObject(baseParameter.SynchronizationId);
                        serverLockObjects.Add(baseParameter.SynchronizationId, newLockObject);
                    }
                    syncServerLockObject = serverLockObjects[baseParameter.SynchronizationId];
                }

                Monitor.TryEnter(syncServerLockObject, 0, ref lockTaken);
                if (!lockTaken) throw new Exception($"{nameof(SyncServerLockObject.SynchronizationId)}: {syncServerLockObject.SynchronizationId}, Synchronization process is already in progress");

                SyncEngine.ProcessPayloadResult baseResult = syncEngine.ProcessPayload(baseParameter);

                if (syncEngine.SyncConfiguration.TimeStampStrategy == SyncConfiguration.TimeStampStrategyEnum.UseGlobalTimeStamp)
                {
                    SyncEngine.PreparePayloadParameter preparePayloadParameter = null;
                    preparePayloadParameter = new SyncEngine.PreparePayloadGlobalTimeStampParameter();
                    preparePayloadParameter.SynchronizationId = baseParameter.SynchronizationId;
                    preparePayloadParameter.CustomInfo = baseParameter.CustomInfo;
                    preparePayloadParameter.PayloadAction = baseParameter.PayloadAction;
                    preparePayloadParameter.Log = baseParameter.Log;
                    ((SyncEngine.PreparePayloadGlobalTimeStampParameter)preparePayloadParameter).LastSync = ((SyncEngine.ProcessPayloadGlobalTimeStampParameter)baseParameter).LastSync;
                    ((SyncEngine.PreparePayloadGlobalTimeStampParameter)preparePayloadParameter).AppliedIds = ((SyncEngine.ProcessPayloadGlobalTimeStampResult)baseResult).AppliedIds;

                    SyncEngine.PreparePayloadGlobalTimeStampResult preparePayloadResult = (SyncEngine.PreparePayloadGlobalTimeStampResult)syncEngine.PreparePayload(preparePayloadParameter);
                    byte[] compressed = preparePayloadResult.GetCompressed();
                    string base64Compressed = Convert.ToBase64String(compressed);
                    jsonResult["payload"] = base64Compressed;
                    jsonResult["maxTimeStamp"] = preparePayloadResult.MaxTimeStamp;
                    jsonResult["sentChanges"] = JArray.FromObject(preparePayloadResult.LogChanges);
                }
                else if (syncEngine.SyncConfiguration.TimeStampStrategy == SyncConfiguration.TimeStampStrategyEnum.UseEachDatabaseInstanceTimeStamp)
                {

                }
                else
                {
                    throw new NotImplementedException(syncEngine.SyncConfiguration.TimeStampStrategy.ToString());
                }
            }
            catch (Exception e)
            {
                jsonResult["isOK"] = false;
                jsonResult["errorMessage"] = e.Message;
                baseParameter.Log.Add($"Error: {e.Message}");
            }
            finally
            {
                jsonResult["log"] = JArray.FromObject(baseParameter.Log);
                jsonResult["serverInserts"] = JArray.FromObject(baseParameter.Inserts);
                jsonResult["serverUpdates"] = JArray.FromObject(baseParameter.Updates);
                jsonResult["serverDeletes"] = JArray.FromObject(baseParameter.Deletes);
                jsonResult["serverConflicts"] = JArray.FromObject(baseParameter.Conflicts);

                if (lockTaken)
                {
                    Monitor.Exit(syncServerLockObject);
                }
            }

            return jsonResult;
        }

        private class SyncServerLockObject
        {
            public readonly string SynchronizationId;

            public SyncServerLockObject(string synchronizationId)
            {
                SynchronizationId = synchronizationId;
            }
        }
    }
}
