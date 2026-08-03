package de.bajorat.blaseunddarm

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
import de.bajorat.blaseunddarm.data.BillingManager
import de.bajorat.blaseunddarm.notification.ReminderManager
import de.bajorat.blaseunddarm.ui.*

class MainActivity : ComponentActivity() {
    private lateinit var dataStore: BDMDataStore
    private lateinit var reminderManager: ReminderManager
    private lateinit var billingManager: BillingManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        dataStore = BDMDataStore(this)
        reminderManager = ReminderManager(this)
        billingManager = BillingManager(this)
        billingManager.startTrialIfNeeded()
        val s = dataStore.settings.value
        reminderManager.scheduleQuietHoursNotifications(s.quietFrom, s.quietTo, s.quietHoursEnabled)

        setContent {
            BlaseUndDarmTheme {
                MainScreen(dataStore, reminderManager, billingManager)
            }
        }
    }
}

@Composable
fun MainScreen(dataStore: BDMDataStore, reminderManager: ReminderManager, billingManager: BillingManager) {
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
                    label = { Text("Erfassen") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Filled.List, "Verlauf") },
                    label = { Text("Verlauf") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = { Icon(Icons.Filled.BarChart, "Statistik") },
                    label = { Text("Statistik") }
                )
                NavigationBarItem(
                    selected = selectedTab == 3,
                    onClick = { selectedTab = 3 },
                    icon = { Icon(Icons.Filled.Settings, "Einstellungen") },
                    label = { Text("Einstellungen") }
                )
            }
        }
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (selectedTab) {
                0 -> LogScreen(dataStore, billingManager, scheduleReminder)
                1 -> HistoryScreen(dataStore, billingManager)
                2 -> StatsScreen(dataStore, billingManager)
                3 -> SettingsScreen(dataStore, reminderManager, billingManager)
            }
        }
    }
}
