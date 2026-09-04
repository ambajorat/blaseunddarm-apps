package de.bajorat.blaseunddarm.ui

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.OptIn
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import de.bajorat.blaseunddarm.data.*
import java.util.concurrent.Executors

// MARK: - Scan-Ergebnis

data class ScanResult(
    val name: String,
    val barcode: String? = null,
    val charriere: Int? = null,
    val material: String? = null
)

// MARK: - Scanner-Sheet (Fullscreen-Dialog)

@kotlin.OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScannerSheet(
    category: ProductCategory,
    onResult: (ScanResult) -> Unit,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    var catalog by remember { mutableStateOf(ProductCatalog.load(context)) }
    var recognizedTexts by remember { mutableStateOf(listOf<String>()) }
    var lastBarcode by remember { mutableStateOf<String?>(null) }
    var autoMatched by remember { mutableStateOf<ScannedProduct?>(null) }
    var charriere by remember { mutableStateOf<Int?>(null) }
    var material by remember { mutableStateOf<String?>(null) }

    // Kamera-Berechtigung
    var hasCamPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED
        )
    }
    val permLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        hasCamPermission = it
    }
    LaunchedEffect(Unit) {
        if (!hasCamPermission) permLauncher.launch(Manifest.permission.CAMERA)
    }

    fun handleBarcode(code: String) {
        if (lastBarcode == code) return
        lastBarcode = code
        val match = catalog.find(code)
        if (match != null) autoMatched = match
    }

    fun handleTexts(texts: List<String>) {
        val filtered = texts
            .map { it.trim() }
            .filter { it.length in 2..80 }
            .filter { !it.all { c -> c.isDigit() } }
            .distinct()

        if (category == ProductCategory.catheter) {
            val allText = texts.joinToString(" ")
            if (charriere == null) charriere = extractCharriere(allText)
            if (material == null) material = extractMaterial(allText)
        }

        if (filtered != recognizedTexts) recognizedTexts = filtered
    }

    fun pickText(text: String) {
        val ch = charriere ?: extractCharriere(text)
        val mat = material ?: extractMaterial(text)

        // Ch-Angabe aus dem Namen entfernen
        var cleanName = text
        val chPatterns = listOf(
            Regex("""(?i)\s*(?:ch|charrière|charriere|fr)[.\s]*\d{1,2}\s*"""),
            Regex("""(?i)\s*\d{1,2}\s*(?:ch|charrière|charriere|fr)\s*""")
        )
        for (p in chPatterns) cleanName = cleanName.replace(p, " ")
        cleanName = cleanName.trim()
        if (cleanName.isEmpty()) cleanName = text

        if (lastBarcode != null) {
            catalog.upsert(context, lastBarcode, cleanName, category, ch, mat)
        }

        onResult(ScanResult(name = cleanName, barcode = lastBarcode, charriere = ch, material = mat))
        onDismiss()
    }

    fun acceptMatch(match: ScannedProduct) {
        val cat = try { ProductCategory.valueOf(match.category) } catch (_: Exception) { category }
        onResult(ScanResult(
            name = match.name, barcode = match.barcode,
            charriere = match.charriere, material = match.material
        ))
        onDismiss()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(tr("Packung scannen")) },
                navigationIcon = {
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = tr("Abbrechen"))
                    }
                }
            )
        }
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            if (!hasCamPermission) {
                // Kein Zugriff
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(tr("Kamera nicht verfügbar"), fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(8.dp))
                        Text(
                            tr("Erlaube den Kamerazugriff in den Geräteeinstellungen, um Packungen zu scannen."),
                            fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            } else {
                // Kamera-Vorschau (obere Hälfte)
                Box(Modifier.weight(1f).fillMaxWidth()) {
                    CameraPreviewWithAnalysis(
                        onBarcode = ::handleBarcode,
                        onTexts = ::handleTexts
                    )
                }

                // Ergebnis-Panel (untere Hälfte)
                Surface(
                    modifier = Modifier.fillMaxWidth().heightIn(max = 280.dp),
                    tonalElevation = 2.dp
                ) {
                    when {
                        autoMatched != null -> {
                            // Katalog-Treffer
                            val match = autoMatched!!
                            Column(
                                Modifier.padding(16.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Icon(
                                    Icons.Default.CheckCircle,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(32.dp)
                                )
                                Spacer(Modifier.height(4.dp))
                                Text(tr("Bekannte Packung"), fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.primary)
                                Spacer(Modifier.height(4.dp))
                                Text(match.name, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                                if (match.charriere != null) {
                                    Text("Ch ${match.charriere}", color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Spacer(Modifier.height(12.dp))
                                Button(onClick = { acceptMatch(match) }) {
                                    Text(tr("Übernehmen"))
                                }
                            }
                        }
                        recognizedTexts.isEmpty() -> {
                            // Hinweis
                            Column(
                                Modifier.fillMaxSize().padding(24.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.Center
                            ) {
                                Text(tr("Packung in die Kamera halten"), fontWeight = FontWeight.SemiBold)
                                Spacer(Modifier.height(4.dp))
                                Text(
                                    tr("Text und Barcodes werden automatisch erkannt."),
                                    fontSize = 13.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                        else -> {
                            // OCR-Textliste
                            Column(Modifier.padding(top = 8.dp)) {
                                Text(
                                    tr("Erkannten Text antippen, um ihn zu übernehmen:"),
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                                )
                                LazyColumn {
                                    itemsIndexed(recognizedTexts) { _, text ->
                                        Row(
                                            Modifier
                                                .fillMaxWidth()
                                                .clickable { pickText(text) }
                                                .padding(horizontal = 16.dp, vertical = 10.dp),
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            Text(text, Modifier.weight(1f), maxLines = 2)
                                            Icon(
                                                Icons.Default.CheckCircle,
                                                contentDescription = tr("Übernehmen"),
                                                tint = MaterialTheme.colorScheme.primary,
                                                modifier = Modifier.size(20.dp)
                                            )
                                        }
                                        HorizontalDivider(Modifier.padding(start = 16.dp))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - CameraX-Vorschau mit ML-Kit-Analyse

@Composable
private fun CameraPreviewWithAnalysis(
    onBarcode: (String) -> Unit,
    onTexts: (List<String>) -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val executor = remember { Executors.newSingleThreadExecutor() }

    val barcodeScanner = remember {
        val opts = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(
                Barcode.FORMAT_EAN_8, Barcode.FORMAT_EAN_13,
                Barcode.FORMAT_DATA_MATRIX, Barcode.FORMAT_CODE_128,
                Barcode.FORMAT_CODE_39
            ).build()
        BarcodeScanning.getClient(opts)
    }
    val textRecognizer = remember {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    }

    DisposableEffect(Unit) {
        onDispose {
            barcodeScanner.close()
            textRecognizer.close()
        }
    }

    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { ctx ->
            val previewView = PreviewView(ctx)
            val cameraProviderFuture = ProcessCameraProvider.getInstance(ctx)
            cameraProviderFuture.addListener({
                val cameraProvider = cameraProviderFuture.get()

                val preview = Preview.Builder().build().also {
                    it.surfaceProvider = previewView.surfaceProvider
                }

                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()

                analysis.setAnalyzer(executor) { imageProxy ->
                    processFrame(imageProxy, barcodeScanner, textRecognizer, onBarcode, onTexts)
                }

                try {
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(
                        lifecycleOwner,
                        CameraSelector.DEFAULT_BACK_CAMERA,
                        preview, analysis
                    )
                } catch (e: Exception) {
                    Log.e("Scanner", "Camera bind failed", e)
                }
            }, ContextCompat.getMainExecutor(ctx))
            previewView
        }
    )
}

@OptIn(ExperimentalGetImage::class)
private fun processFrame(
    imageProxy: ImageProxy,
    barcodeScanner: com.google.mlkit.vision.barcode.BarcodeScanner,
    textRecognizer: com.google.mlkit.vision.text.TextRecognizer,
    onBarcode: (String) -> Unit,
    onTexts: (List<String>) -> Unit
) {
    val mediaImage = imageProxy.image ?: run { imageProxy.close(); return }
    val inputImage = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)

    // Barcode + OCR parallel
    var barcodesDone = false
    var textDone = false
    fun maybeClose() { if (barcodesDone && textDone) imageProxy.close() }

    barcodeScanner.process(inputImage)
        .addOnSuccessListener { barcodes ->
            for (b in barcodes) {
                val value = b.rawValue
                if (!value.isNullOrEmpty()) onBarcode(value)
            }
        }
        .addOnCompleteListener { barcodesDone = true; maybeClose() }

    textRecognizer.process(inputImage)
        .addOnSuccessListener { visionText ->
            val lines = visionText.textBlocks.flatMap { block ->
                block.lines.map { it.text }
            }
            if (lines.isNotEmpty()) onTexts(lines)
        }
        .addOnCompleteListener { textDone = true; maybeClose() }
}

// MARK: - ScanButton (wiederverwendbar)

@Composable
fun ScanButton(
    category: ProductCategory,
    onResult: (ScanResult) -> Unit
) {
    var showScanner by remember { mutableStateOf(false) }

    IconButton(onClick = { showScanner = true }) {
        Icon(
            painter = androidx.compose.ui.res.painterResource(
                android.R.drawable.ic_menu_camera
            ),
            contentDescription = tr("Packung scannen"),
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(24.dp)
        )
    }

    if (showScanner) {
        FullScreenDialog(onDismiss = { showScanner = false }) {
            ScannerSheet(
                category = category,
                onResult = onResult,
                onDismiss = { showScanner = false }
            )
        }
    }
}

// Fullscreen-Dialog-Wrapper
@Composable
private fun FullScreenDialog(
    onDismiss: () -> Unit,
    content: @Composable () -> Unit
) {
    androidx.compose.ui.window.Dialog(
        onDismissRequest = onDismiss,
        properties = androidx.compose.ui.window.DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false
        )
    ) {
        Surface(Modifier.fillMaxSize()) {
            content()
        }
    }
}

// MARK: - Katalog-Übersicht

@kotlin.OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProductCatalogScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    var catalog by remember { mutableStateOf(ProductCatalog.load(context)) }

    val catheterProducts = catalog.products(ProductCategory.catheter)
    val medProducts = catalog.products(ProductCategory.medication)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(tr("Gescannte Packungen")) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.Close, contentDescription = tr("Abbrechen"))
                    }
                }
            )
        }
    ) { padding ->
        if (catalog.products.isEmpty()) {
            Box(
                Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(tr("Noch keine Scans"), fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(8.dp))
                    Text(
                        tr("Gescannte Packungen erscheinen hier und werden beim nächsten Mal automatisch erkannt."),
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        } else {
            LazyColumn(
                Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                if (catheterProducts.isNotEmpty()) {
                    item {
                        Text(
                            tr("Katheter"),
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.padding(vertical = 8.dp)
                        )
                    }
                    items(catheterProducts.size) { idx ->
                        val product = catheterProducts[idx]
                        CatalogRow(product) {
                            catalog.remove(context, product.id)
                            catalog = ProductCatalog.load(context)
                        }
                    }
                }
                if (medProducts.isNotEmpty()) {
                    item {
                        Text(
                            tr("Medikamente"),
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.padding(vertical = 8.dp)
                        )
                    }
                    items(medProducts.size) { idx ->
                        val product = medProducts[idx]
                        CatalogRow(product) {
                            catalog.remove(context, product.id)
                            catalog = ProductCatalog.load(context)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CatalogRow(product: ScannedProduct, onDelete: () -> Unit) {
    Card(Modifier.fillMaxWidth()) {
        Row(
            Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text(product.name)
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (product.barcode != null) {
                        Text(product.barcode, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (product.charriere != null) {
                        Text("Ch ${product.charriere}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (product.material != null) {
                        Text(product.material, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            IconButton(onClick = onDelete) {
                Icon(Icons.Default.Close, contentDescription = tr("Entfernen"), modifier = Modifier.size(16.dp))
            }
        }
    }
}
