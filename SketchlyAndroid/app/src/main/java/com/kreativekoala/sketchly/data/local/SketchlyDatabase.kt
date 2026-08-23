package com.kreativekoala.sketchly.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [DrawingSessionEntity::class],
    version = 1,
    exportSchema = false
)
abstract class SketchlyDatabase : RoomDatabase() {
    abstract fun drawingSessionDao(): DrawingSessionDao
}
