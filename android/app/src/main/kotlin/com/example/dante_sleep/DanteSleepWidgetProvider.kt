package com.example.dante_sleep

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.SystemClock
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class DanteSleepWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.dante_sleep_widget_layout)

            // Retrieve data from SharedPreferences sent by Flutter
            val isSleeping = widgetData.getBoolean("is_sleeping", false)
            val statusLabel = widgetData.getString("status_label", "Acordado há")
            val statusSince = widgetData.getString("status_since", "")
            
            // Safe-cast retrieval for state_start_time to prevent ClassCastException
            val stateStartTimeVal = widgetData.all["state_start_time"]
            val stateStartTime: Long = when (stateStartTimeVal) {
                is Long -> stateStartTimeVal
                is Int -> stateStartTimeVal.toLong()
                is Number -> stateStartTimeVal.toLong()
                is String -> stateStartTimeVal.toLongOrNull() ?: 0L
                else -> 0L
            }

            val isLightTheme = widgetData.getBoolean("is_light_theme", true)

            // Apply styling and assets based on theme and state
            if (isLightTheme) {
                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_bg_awake)
                views.setTextColor(R.id.widget_status_label, 0x9012233F.toInt())
                views.setTextColor(R.id.widget_chronometer, 0xFF12233F.toInt())
                views.setTextColor(R.id.widget_status_since, 0x7012233F.toInt())

                if (isSleeping) {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_moon)
                    views.setInt(R.id.widget_icon, "setColorFilter", 0xFF12233F.toInt())
                } else {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_sun)
                    views.setInt(R.id.widget_icon, "setColorFilter", 0xFF2A6CE8.toInt())
                }
            } else {
                views.setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_bg_sleeping)
                views.setTextColor(R.id.widget_status_label, 0xB0EADFFF.toInt())
                views.setTextColor(R.id.widget_chronometer, 0xFFEADFFF.toInt())
                views.setTextColor(R.id.widget_status_since, 0x80EADFFF.toInt())

                if (isSleeping) {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_moon)
                    views.setInt(R.id.widget_icon, "setColorFilter", 0xFFEADFFF.toInt())
                } else {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_sun)
                    views.setInt(R.id.widget_icon, "setColorFilter", 0xFFFFD54F.toInt())
                }
            }

            // Update texts
            views.setTextViewText(R.id.widget_status_label, statusLabel)
            views.setTextViewText(R.id.widget_status_since, statusSince)

            // Configure Chronometer
            if (stateStartTime > 0L) {
                val timeDiff = System.currentTimeMillis() - stateStartTime
                val baseTime = SystemClock.elapsedRealtime() - timeDiff
                views.setChronometer(R.id.widget_chronometer, baseTime, null, true)
            } else {
                views.setChronometer(R.id.widget_chronometer, SystemClock.elapsedRealtime(), null, false)
            }

            // Setup onClick to launch the main app Activity
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 
                0, 
                intent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
