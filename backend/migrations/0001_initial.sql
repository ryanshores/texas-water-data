CREATE TABLE reservoirs (
  id TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  short_name TEXT NOT NULL,
  full_name TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  basin TEXT,
  region TEXT,
  is_water_supply INTEGER NOT NULL CHECK (is_water_supply IN (0, 1)),
  is_flood_control INTEGER NOT NULL CHECK (is_flood_control IN (0, 1)),
  conservation_pool_elevation REAL,
  updated_at TEXT NOT NULL
);

CREATE TABLE observations (
  reservoir_id TEXT NOT NULL REFERENCES reservoirs(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  percent_full REAL,
  elevation REAL,
  surface_area REAL,
  reservoir_storage REAL,
  conservation_storage REAL,
  conservation_capacity REAL,
  dead_pool_capacity REAL,
  ingested_at TEXT NOT NULL,
  PRIMARY KEY (reservoir_id, date)
);

CREATE INDEX observations_date_idx ON observations(date);
CREATE INDEX observations_reservoir_date_idx ON observations(reservoir_id, date DESC);

CREATE TABLE ingestion_runs (
  id TEXT PRIMARY KEY,
  started_at TEXT NOT NULL,
  completed_at TEXT,
  status TEXT NOT NULL,
  record_count INTEGER NOT NULL DEFAULT 0,
  error TEXT
);
