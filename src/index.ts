import { Elm } from './Main.elm';
import { Capacitor } from '@capacitor/core';
import { CapacitorSQLite, SQLiteConnection, SQLiteDBConnection } from '@capacitor-community/sqlite';

const sqlite = new SQLiteConnection(CapacitorSQLite);
let db: SQLiteDBConnection | null = null;

const DB_NAME = 'omedd_diary.db';

async function initDatabase() {
  const isNative = Capacitor.isNativePlatform();

  if (isNative) {
    try {
      const ret = await sqlite.checkConnectionsConsistency();
      const isConn = (await sqlite.isConnection(DB_NAME, false)).result;
      
      if (ret.result && isConn) {
        db = await sqlite.retrieveConnection(DB_NAME, false);
      } else {
        db = await sqlite.createConnection(DB_NAME, false, 'no-encryption', 1, false);
      }
      
      await db.open();

      await db.execute(`
        CREATE TABLE IF NOT EXISTS bolus_entries (
          id TEXT PRIMARY KEY,
          drug_id TEXT NOT NULL,
          drug_name TEXT NOT NULL,
          timestamp_ms INTEGER NOT NULL,
          dose_mg REAL NOT NULL,
          is_prn INTEGER NOT NULL,
          omedd REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS patch_entries (
          id TEXT PRIMARY KEY,
          drug_id TEXT NOT NULL,
          drug_name TEXT NOT NULL,
          applied_at_ms INTEGER NOT NULL,
          removed_at_ms INTEGER,
          rated_delivery_rate_mcg REAL NOT NULL,
          omedd_per_hour REAL NOT NULL
        );
      `);
    } catch (err) {
      console.warn('Native SQLite init failed, falling back to local storage', err);
      db = null;
    }
  }
}

// Fallback pure-web local storage handlers
function getLocalWebData() {
  const boluses = JSON.parse(localStorage.getItem('omedd_boluses') || '[]');
  const patches = JSON.parse(localStorage.getItem('omedd_patches') || '[]');
  return { boluses, patches };
}

function saveLocalWebBolus(entry: any) {
  const { boluses, patches } = getLocalWebData();
  boluses.unshift(entry);
  localStorage.setItem('omedd_boluses', JSON.stringify(boluses));
}

function saveLocalWebPatch(entry: any) {
  const { boluses, patches } = getLocalWebData();
  patches.unshift(entry);
  localStorage.setItem('omedd_patches', JSON.stringify(patches));
}

function removeLocalWebPatch(patchId: string) {
  const { boluses, patches } = getLocalWebData();
  const updated = patches.map((p: any) => p.id === patchId ? { ...p, removedAtMs: Date.now() } : p);
  localStorage.setItem('omedd_patches', JSON.stringify(updated));
}

// Elm Initialization
document.addEventListener('DOMContentLoaded', async () => {
  const appContainer = document.getElementById('elm-app');
  if (!appContainer) return;

  const app = Elm.Main.init({
    node: appContainer,
    flags: null
  });

  await initDatabase();

  // Port Subscriptions
  app.ports.requestInitialData.subscribe(async () => {
    if (db) {
      const bRes = await db.query('SELECT id, drug_id as drugId, drug_name as drugName, timestamp_ms as timestampMs, dose_mg as doseMg, is_prn as isPrn, omedd FROM bolus_entries ORDER BY timestamp_ms DESC;');
      const pRes = await db.query('SELECT id, drug_id as drugId, drug_name as drugName, applied_at_ms as appliedAtMs, removed_at_ms as removedAtMs, rated_delivery_rate_mcg as ratedDeliveryRateMcg, omedd_per_hour as omeddPerHour FROM patch_entries ORDER BY applied_at_ms DESC;');

      const boluses = (bRes.values || []).map(b => ({ ...b, isPrn: Boolean(b.isPrn) }));
      const patches = pRes.values || [];

      app.ports.onInitialDataLoaded.send({ boluses, patches });
    } else {
      app.ports.onInitialDataLoaded.send(getLocalWebData());
    }
  });

  app.ports.saveBolus.subscribe(async (bolus: any) => {
    if (db) {
      await db.run(
        `INSERT INTO bolus_entries (id, drug_id, drug_name, timestamp_ms, dose_mg, is_prn, omedd) VALUES (?, ?, ?, ?, ?, ?, ?);`,
        [bolus.id, bolus.drugId, bolus.drugName, bolus.timestampMs, bolus.doseMg, bolus.isPrn ? 1 : 0, bolus.omedd]
      );
    } else {
      saveLocalWebBolus(bolus);
    }
  });

  app.ports.savePatch.subscribe(async (patch: any) => {
    if (db) {
      await db.run(
        `INSERT INTO patch_entries (id, drug_id, drug_name, applied_at_ms, removed_at_ms, rated_delivery_rate_mcg, omedd_per_hour) VALUES (?, ?, ?, ?, ?, ?, ?);`,
        [patch.id, patch.drugId, patch.drugName, patch.appliedAtMs, patch.removedAtMs, patch.ratedDeliveryRateMcg, patch.omeddPerHour]
      );
    } else {
      saveLocalWebPatch(patch);
    }
  });

  app.ports.removePatch.subscribe(async (patchId: string) => {
    const now = Date.now();
    if (db) {
      await db.run(`UPDATE patch_entries SET removed_at_ms = ? WHERE id = ?;`, [now, patchId]);
    } else {
      removeLocalWebPatch(patchId);
    }
  });
});