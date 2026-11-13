package de.bajorat.blaseunddarm.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Card
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.bajorat.blaseunddarm.data.BowelStats
import de.bajorat.blaseunddarm.data.I18n
import de.bajorat.blaseunddarm.data.StatsBucket
import de.bajorat.blaseunddarm.data.StatsGranularity
import de.bajorat.blaseunddarm.data.StatsMath
import de.bajorat.blaseunddarm.data.StatsTrendLine
import de.bajorat.blaseunddarm.data.VolumeBlock
import de.bajorat.blaseunddarm.data.tr
import de.bajorat.blaseunddarm.data.trf
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

// ==================== STATISTIK-DIAGRAMME (2.7, Parität zu iOS 4.22) ====================

private fun bucketLabel(date: LocalDate, granularity: StatsGranularity): String {
    val locale = if (I18n.isGerman) Locale.GERMAN else Locale.ENGLISH
    return when (granularity) {
        StatsGranularity.MONTH -> date.format(DateTimeFormatter.ofPattern("MMM yy", locale))
        else -> date.format(DateTimeFormatter.ofPattern("dd.MM.", locale))
    }
}

private fun granularitySuffix(granularity: StatsGranularity): String = when (granularity) {
    StatsGranularity.DAY -> ""
    StatsGranularity.WEEK -> " · " + tr("Ø je Woche")
    StatsGranularity.MONTH -> " · " + tr("Ø je Monat")
}

private fun trendText(trend: StatsTrendLine): String {
    val pct = trend.changePercent ?: return tr("Gestrichelte Linie: Trend im Zeitraum")
    if (kotlin.math.abs(pct) < 3) return tr("Trend (gestrichelte Linie): gleichbleibend")
    val change = (if (pct > 0) "+" else "−") + kotlin.math.abs(pct) + " %"
    return trf("Trend (gestrichelte Linie): {0} im Zeitraum", change)
}

/**
 * Balkendiagramm mit gestrichelter Trendlinie. Die x-Achse ist zeitproportional:
 * ein Tagesbalken ist einen Tag breit, ein Wochenbalken sieben, ein Monatsbalken den Monat.
 * `second` (optional) wird als schmaler zweiter Balken daneben gezeichnet.
 */
@Composable
fun BarTrendChart(
    title: String,
    buckets: List<StatsBucket>,
    granularity: StatsGranularity,
    color: Color,
    value: (StatsBucket) -> Double,
    secondColor: Color = Color.Unspecified,
    second: ((StatsBucket) -> Double)? = null
) {
    if (buckets.isEmpty()) return
    val trend = StatsMath.trend(buckets, value)
    val gridColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.25f)
    val trendColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    val maxValue = maxOf(
        buckets.maxOf(value),
        trend?.let { maxOf(it.startValue, it.endValue) } ?: 0.0,
        1.0
    )
    val x0 = buckets.first().start.toEpochDay().toDouble()
    val x1 = buckets.last().start.toEpochDay().toDouble() + buckets.last().lengthDays
    val span = maxOf(x1 - x0, 1.0)

    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(title + granularitySuffix(granularity), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = muted)
            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth()) {
                Column(Modifier.height(150.dp).padding(end = 6.dp), verticalArrangement = Arrangement.SpaceBetween) {
                    Text(Math.round(maxValue).toString(), fontSize = 9.sp, color = muted)
                    Text("0", fontSize = 9.sp, color = muted)
                }
                Canvas(Modifier.weight(1f).height(150.dp)) {
                    val w = size.width
                    val h = size.height
                    // Hilfslinien bei 0, 50 und 100 %
                    for (i in 0..2) {
                        val y = h * i / 2f
                        drawLine(gridColor, Offset(0f, y), Offset(w, y), strokeWidth = 1f)
                    }
                    val corner = CornerRadius(2.dp.toPx(), 2.dp.toPx())
                    for (b in buckets) {
                        val left = ((b.start.toEpochDay() - x0) / span * w).toFloat()
                        val full = (b.lengthDays / span * w).toFloat()
                        val gap = minOf(full * 0.15f, 2.dp.toPx())
                        val barWidth = maxOf(full - 2 * gap, 1f)
                        val v = value(b)
                        if (second == null) {
                            if (v > 0) {
                                val bh = (v / maxValue * h).toFloat()
                                drawRoundRect(color, Offset(left + gap, h - bh), Size(barWidth, bh), corner)
                            }
                        } else {
                            val half = barWidth / 2f
                            if (v > 0) {
                                val bh = (v / maxValue * h).toFloat()
                                drawRoundRect(color, Offset(left + gap, h - bh), Size(half, bh), corner)
                            }
                            val v2 = second(b)
                            if (v2 > 0) {
                                val bh2 = (v2 / maxValue * h).toFloat()
                                drawRoundRect(secondColor, Offset(left + gap + half, h - bh2), Size(half, bh2), corner)
                            }
                        }
                    }
                    if (trend != null) {
                        val sx = ((trend.startX - x0) / span * w).toFloat()
                        val ex = ((trend.endX - x0) / span * w).toFloat()
                        val sy = (h - trend.startValue / maxValue * h).toFloat()
                        val ey = (h - trend.endValue / maxValue * h).toFloat()
                        drawLine(
                            trendColor, Offset(sx, sy), Offset(ex, ey),
                            strokeWidth = 2.dp.toPx(),
                            pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx()))
                        )
                    }
                }
            }
            Row(Modifier.fillMaxWidth().padding(top = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(bucketLabel(buckets.first().start, granularity), fontSize = 9.sp, color = muted)
                Text(bucketLabel(buckets.last().start, granularity), fontSize = 9.sp, color = muted)
            }
            if (second != null) {
                Row(Modifier.fillMaxWidth().padding(top = 4.dp), horizontalArrangement = Arrangement.Center) {
                    Text("● " + tr("Gänge gesamt"), fontSize = 10.sp, color = color)
                    Spacer(Modifier.width(14.dp))
                    Text("● " + tr("davon mit Stuhl"), fontSize = 10.sp, color = secondColor)
                }
            }
            if (trend != null) {
                Text(trendText(trend), fontSize = 10.sp, color = muted, modifier = Modifier.padding(top = 4.dp))
            }
        }
    }
}

/** Zeile „Name · Balken · Wert“ für die Tageszeit- und Bristol-Karten. */
@Composable
private fun BarRow(label: String, sub: String?, fraction: Float, barColor: Color, trailing: String) {
    val track = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.2f)
    Row(Modifier.fillMaxWidth().padding(vertical = 3.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.width(116.dp)) {
            Text(label, fontSize = 12.sp, maxLines = 1)
            if (sub != null) Text(sub, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Canvas(Modifier.weight(1f).height(8.dp)) {
            val r = CornerRadius(size.height / 2f, size.height / 2f)
            drawRoundRect(track, Offset.Zero, Size(size.width, size.height), r)
            val f = fraction.coerceIn(0f, 1f)
            if (f > 0f) drawRoundRect(barColor, Offset.Zero, Size(maxOf(size.width * f, size.height), size.height), r)
        }
        Text(trailing, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 8.dp))
    }
}

/** Ø Urinmenge je Entleerung in 3-Stunden-Blöcken. */
@Composable
fun DaytimeVolumeCard(blocks: List<VolumeBlock>) {
    if (blocks.isEmpty()) return
    val maxMl = maxOf(blocks.maxOf { it.avgMl }, 1)
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            Text(tr("Menge nach Tageszeit"), fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            Spacer(Modifier.height(6.dp))
            blocks.forEach { b ->
                BarRow(tr(b.label), b.rangeText, b.avgMl.toFloat() / maxMl, Orange, trf("Ø {0} ml ({1}×)", b.avgMl, b.count))
            }
            Text(
                tr("Durchschnittliche Urinmenge je Entleerung in 3-Stunden-Blöcken, im gewählten Zeitraum."),
                fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp)
            )
        }
    }
}

/** Darm-Karte: Frequenz bzw. Abstand, letzter Stuhlgang, Bristol-Bänder. */
@Composable
fun BowelCard(stats: BowelStats?) {
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            Text(tr("Darm"), fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            Spacer(Modifier.height(6.dp))
            if (stats == null) {
                Text(tr("Noch keine Stuhlgänge im Zeitraum"), fontSize = 12.sp, color = muted)
            } else {
                val gap = stats.avgGapDays
                val lead = when {
                    // Mehrfach täglich (z. B. neurogener Darm): Frequenz statt Tages-Abstand
                    stats.perDay >= 1.5 -> trf("Ø {0}× pro Tag", "%.1f".format(stats.perDay))
                    gap != null -> trf("Ø Abstand {0} Tage", "%.1f".format(gap))
                    else -> null
                }
                val last = if (stats.lastAgoDays == 0) trf("zuletzt vor {0} Std", stats.lastAgoHours)
                           else trf("zuletzt vor {0} Tagen", stats.lastAgoDays)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (lead != null) {
                        Text(lead, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.width(14.dp))
                    }
                    Text(last, fontSize = 12.sp, color = muted)
                }
                if (stats.typed > 0) {
                    Text(trf("{0} Stuhlgänge im Zeitraum, nach Bristol-Typ erfasst.", stats.typed), fontSize = 12.sp, color = muted, modifier = Modifier.padding(top = 6.dp, bottom = 2.dp))
                    val total = stats.typed.toFloat()
                    BarRow(tr("Zu fest (Typ 1–2)"), null, stats.hard / total, Orange, stats.hard.toString())
                    BarRow(tr("Unauffällig (Typ 3–5)"), null, stats.ok / total, Green, stats.ok.toString())
                    BarRow(tr("Zu weich (Typ 6–7)"), null, stats.loose / total, Color(0xFF4A90D9), stats.loose.toString())
                    Text(
                        tr("Typ 3 bis 5 gilt als unauffällig. Häufungen bei Typ 1 und 2 sprechen für zu wenig Flüssigkeit oder zu lange Abstände."),
                        fontSize = 10.sp, color = muted, modifier = Modifier.padding(top = 4.dp)
                    )
                }
            }
        }
    }
}

/** Wochen-/Monatsübersicht ab 3 Monaten: Durchschnitt pro Tag mit Einträgen. */
@Composable
fun BucketTable(buckets: List<StatsBucket>, granularity: StatsGranularity) {
    val weekly = granularity == StatsGranularity.WEEK
    val muted = MaterialTheme.colorScheme.onSurfaceVariant
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(
                if (weekly) tr("Wochenübersicht (Ø pro Tag)") else tr("Monatsübersicht (Ø pro Tag)"),
                fontSize = 12.sp, fontWeight = FontWeight.Bold, color = muted
            )
            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth().padding(bottom = 4.dp)) {
                Text(if (weekly) tr("Woche ab") else tr("Monat"), Modifier.weight(1f), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = muted)
                Text(tr("Urin"), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = muted)
                Spacer(Modifier.width(16.dp))
                Text(tr("Gänge"), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = muted)
                Spacer(Modifier.width(16.dp))
                Text(tr("Stuhl"), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = muted)
            }
            HorizontalDivider()
            buckets.filter { it.activeDays > 0 }.forEach { b ->
                Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                    Text(bucketLabel(b.start, granularity), Modifier.weight(1f), fontSize = 12.sp)
                    Text(trf("{0} ml", Math.round(b.avgMl)), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Orange)
                    Spacer(Modifier.width(16.dp))
                    Text("%.1f".format(b.avgVisits), fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.width(16.dp))
                    Text("%.1f".format(b.avgBowel), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Purple)
                }
                HorizontalDivider()
            }
        }
    }
}
