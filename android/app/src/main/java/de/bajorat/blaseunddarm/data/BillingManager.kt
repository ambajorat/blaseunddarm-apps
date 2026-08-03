package de.bajorat.blaseunddarm.data

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class BillingManager(private val context: Context) : PurchasesUpdatedListener {

    companion object {
        const val MONTHLY_ID = "blaseunddarm.premium.monthly"
        const val YEARLY_ID = "blaseunddarm.premium.yearly"
        private const val TRIAL_START_KEY = "trial_start_date"
        private const val TRIAL_DAYS = 30
    }

    private val _isPremium = MutableStateFlow(false)
    val isPremium: StateFlow<Boolean> = _isPremium

    private val _isTrialActive = MutableStateFlow(false)
    val isTrialActive: StateFlow<Boolean> = _isTrialActive

    private val _trialDaysLeft = MutableStateFlow(0)
    val trialDaysLeft: StateFlow<Int> = _trialDaysLeft

    private val _monthlyPrice = MutableStateFlow("")
    val monthlyPrice: StateFlow<String> = _monthlyPrice

    private val _yearlyPrice = MutableStateFlow("")
    val yearlyPrice: StateFlow<String> = _yearlyPrice

    private var billingClient: BillingClient
    private var monthlyDetails: ProductDetails? = null
    private var yearlyDetails: ProductDetails? = null

    val hasAccess: Boolean get() = _isPremium.value || _isTrialActive.value

    init {
        checkTrialStatus()
        billingClient = BillingClient.newBuilder(context)
            .setListener(this)
            .enablePendingPurchases()
            .build()
        connectBilling()
    }

    // MARK: - Trial

    fun startTrialIfNeeded() {
        val prefs = context.getSharedPreferences("bb_billing", Context.MODE_PRIVATE)
        if (!prefs.contains(TRIAL_START_KEY)) {
            prefs.edit().putLong(TRIAL_START_KEY, System.currentTimeMillis()).apply()
        }
        checkTrialStatus()
    }

    private fun checkTrialStatus() {
        val prefs = context.getSharedPreferences("bb_billing", Context.MODE_PRIVATE)
        val startTime = prefs.getLong(TRIAL_START_KEY, 0L)
        if (startTime == 0L) {
            prefs.edit().putLong(TRIAL_START_KEY, System.currentTimeMillis()).apply()
            _isTrialActive.value = true
            _trialDaysLeft.value = TRIAL_DAYS
            return
        }
        val elapsed = (System.currentTimeMillis() - startTime) / (1000 * 60 * 60 * 24)
        val remaining = (TRIAL_DAYS - elapsed).toInt().coerceAtLeast(0)
        _trialDaysLeft.value = remaining
        _isTrialActive.value = remaining > 0
    }

    // MARK: - Billing

    private fun connectBilling() {
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    queryProducts()
                    queryPurchases()
                }
            }
            override fun onBillingServiceDisconnected() {}
        })
    }

    private fun queryProducts() {
        val productList = listOf(
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(MONTHLY_ID)
                .setProductType(BillingClient.ProductType.SUBS)
                .build(),
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(YEARLY_ID)
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        )
        val params = QueryProductDetailsParams.newBuilder().setProductList(productList).build()
        billingClient.queryProductDetailsAsync(params) { _, detailsList ->
            detailsList.forEach { details ->
                val price = details.subscriptionOfferDetails?.firstOrNull()?.pricingPhases?.pricingPhaseList?.firstOrNull()?.formattedPrice ?: ""
                when (details.productId) {
                    MONTHLY_ID -> { monthlyDetails = details; _monthlyPrice.value = price }
                    YEARLY_ID -> { yearlyDetails = details; _yearlyPrice.value = price }
                }
            }
        }
    }

    private fun queryPurchases() {
        billingClient.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build()
        ) { _, purchases ->
            _isPremium.value = purchases.any { it.purchaseState == Purchase.PurchaseState.PURCHASED }
            purchases.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED && !it.isAcknowledged }.forEach { purchase ->
                billingClient.acknowledgePurchase(
                    AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()
                ) {}
            }
        }
    }

    fun purchaseMonthly(activity: Activity) = launchPurchase(activity, monthlyDetails)
    fun purchaseYearly(activity: Activity) = launchPurchase(activity, yearlyDetails)

    private fun launchPurchase(activity: Activity, details: ProductDetails?) {
        details ?: return
        val offerToken = details.subscriptionOfferDetails?.firstOrNull()?.offerToken ?: return
        val productParams = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(details)
            .setOfferToken(offerToken)
            .build()
        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productParams))
            .build()
        billingClient.launchBillingFlow(activity, params)
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: List<Purchase>?) {
        if (result.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            purchases.forEach { purchase ->
                if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
                    _isPremium.value = true
                    if (!purchase.isAcknowledged) {
                        billingClient.acknowledgePurchase(
                            AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()
                        ) {}
                    }
                }
            }
        }
    }
}
