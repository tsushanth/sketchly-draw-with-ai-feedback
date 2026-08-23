package com.kreativekoala.sketchly.data.local

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface DrawingSessionDao {
    @Query("SELECT * FROM drawing_sessions ORDER BY createdAt DESC")
    fun observeAll(): Flow<List<DrawingSessionEntity>>

    @Query("SELECT * FROM drawing_sessions WHERE id = :id")
    suspend fun getById(id: Long): DrawingSessionEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(session: DrawingSessionEntity): Long

    @Delete
    suspend fun delete(session: DrawingSessionEntity)
}
