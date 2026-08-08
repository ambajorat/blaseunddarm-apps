package de.bajorat.blaseunddarm

import de.bajorat.blaseunddarm.notification.AlertWorker
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import de.bajorat.blaseunddarm.data.BDMDataStore
import de.bajorat.blaseunddarm.notification.ReminderManager
import de.bajorat.blaseunddarm.ui.*

class MainActivity : ComponentActivity() {
    private lateinit var dataStore: BDMDataStore
    private lateinit var reminderManager: ReminderManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AlertWorker.schedule(this)
        enableEdgeToEdge()

        dataStore = BDMDataStore(this)
        reminderManager = ReminderManager(this)
        val s = dataStore.settings.value
        reminderManager.scheduleQuietHoursNotifications(s.quietFrom, s.quietTo, s.quietHoursEnabled)

        setContent {
            BlaseUndDarmTheme {
                MainScreen(dataStore, reminderManager)
            }
        }
    }
}

@Composable
fun MainScreen(dataStore: BDMDataStore, reminderManager: ReminderManager) {
    var selectedTab by remember { mutableIntStateOf(0) }
    val settings by dataStore.settings.collectAsState()

    val scheduleReminder: () -> Unit = {
        if (settings.reminderEnabled) {
            reminderManager.scheduleReminder(
                afterMinutes = settings.intervalMinutes,
                quietFrom = settings.quietFrom,
                quietTo = settings.quietTo,
                quietEnabled = settings.quietHoursEnabled
            )
        }
    }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = { Icon(Icons.Filled.Add, "Erfassen") },
                    label = { Text("Erfassen", maxLines = 1, softWrap = false) }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Filled.List, "Verlauf") },
                    label = { Text("Verlauf", maxLines = 1, softWrap = false) }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = { Icon(Icons.Filled.BarChart, "Statistik") },
                    label = { Text("Statistik", maxLines = 1, softWrap = false) }
                )
                NavigationBarItem(
                    selected = selectedTab == 3,
                    onClick = { selectedTab = 3 },
                    icon = { Icon(Icons.Filled.Notifications, "Hinweise") },
                    label = { Text("Hinweise", maxLines = 1, softWrap = false) }
                )
                NavigationBarItem(
                    selected = selectedTab == 4,
                    onClick = { selectedTab = 4 },
                    icon = { Icon(Icons.Filled.Settings, "Einstellungen") },
                    label = { Text("Einstellungen", maxLines = 1, softWrap = false) }
                )
            }
        }
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (selectedTab) {
                0 -> LogScreen(dataStore, scheduleReminder)
                1 -> HistoryScreen(dataStore)
                2 -> StatsScreen(dataStore)
                3 -> AlertsScreen(dataStore)
                4 -> SettingsScreen(dataStore, reminderManager)
            }
        }
    }
}
