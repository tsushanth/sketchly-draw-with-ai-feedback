package com.kreativekoala.sketchly.di

import android.content.Context
import androidx.room.Room
import com.kreativekoala.sketchly.data.local.DrawingSessionDao
import com.kreativekoala.sketchly.data.local.SketchlyDatabase
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideSketchlyDatabase(@ApplicationContext context: Context): SketchlyDatabase =
        Room.databaseBuilder(context, SketchlyDatabase::class.java, "sketchly.db")
            .fallbackToDestructiveMigration()
            .build()

    @Provides
    fun provideDrawingSessionDao(db: SketchlyDatabase): DrawingSessionDao = db.drawingSessionDao()
}
