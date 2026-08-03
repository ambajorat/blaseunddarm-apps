package de.bajorat.blaseunddarm.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val Orange = Color(0xFFE8923A)
val OrangeDark = Color(0xFFD07A28)
val OrangeLight = Color(0x1FE8923A)
val Purple = Color(0xFF9B7EC8)
val Green = Color(0xFF5A9A6E)
val Red = Color(0xFFC0392B)

val DarkBg = Color(0xFF111111)
val DarkCard = Color(0xFF1A1A1A)
val DarkBorder = Color(0xFF2A2A2A)
val TextMuted = Color(0xFF8A8580)

private val DarkColorScheme = darkColorScheme(
    primary = Orange,
    onPrimary = Color(0xFF111111),
    secondary = Purple,
    background = DarkBg,
    surface = DarkCard,
    surfaceVariant = DarkBorder,
    onBackground = Color(0xFFF0ECE4),
    onSurface = Color(0xFFF0ECE4),
    onSurfaceVariant = TextMuted,
    error = Red,
    outline = DarkBorder
)

private val LightColorScheme = lightColorScheme(
    primary = Orange,
    onPrimary = Color.White,
    secondary = Purple,
    background = Color(0xFFF7F6F4),
    surface = Color.White,
    surfaceVariant = Color(0xFFEDECEA),
    onBackground = Color(0xFF1A1A1A),
    onSurface = Color(0xFF1A1A1A),
    onSurfaceVariant = Color(0xFF6B6560),
    error = Red,
    outline = Color(0xFFCCCAC7)
)

@Composable
fun BlaseUndDarmTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    MaterialTheme(
        colorScheme = colorScheme,
        content = content
    )
}
