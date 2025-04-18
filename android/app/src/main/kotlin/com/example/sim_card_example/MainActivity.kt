package com.example.sim_card_example

import android.os.Build
import android.os.Bundle
import android.content.Context
import android.telephony.SubscriptionManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // 與 Dart 端對應的 Channel 名稱
    private val CHANNEL = "com.example.sim_card_example/sim"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSimData" -> {
                    val simDataList = getSimData()
                    result.success(simDataList)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 取得多張 SIM 卡資訊
     * 回傳為 List<Map<String, Any?>>,
     * 使用 try-catch 包住，抓不到的話回傳 "抓不到"
     */
    private fun getSimData(): List<Map<String, Any?>> {
        val simInfoList = mutableListOf<Map<String, Any?>>()

        val subscriptionManager =
            getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
        val activeSubscriptionInfoList = subscriptionManager.activeSubscriptionInfoList

        if (activeSubscriptionInfoList != null) {
            for (info in activeSubscriptionInfoList) {

                // subscriptionId: SIM 卡在 Android 系統中的訂閱 ID (唯一標識)
                val subscriptionId = try { info.subscriptionId } catch (e: Exception) { "抓不到" }

                // slotIndex: SIM 卡槽序號 (0, 1...)
                val slotIndex = try { info.simSlotIndex } catch (e: Exception) { "抓不到" }

                // displayName: 一般顯示給使用者的名稱 (可能是電信商或用戶自訂)
                val displayName = try { info.displayName?.toString() } catch (e: Exception) { "抓不到" }

                // carrierName: 電信業者名稱
                val carrierName = try { info.carrierName?.toString() } catch (e: Exception) { "抓不到" }

                // iccId: SIM 卡的 ICCID (卡片序號)
                val iccId = try { info.iccId } catch (e: Exception) { "抓不到" }

                // number: 電話號碼 (若電信商/系統沒設定，可能抓不到或空)
                val number = try { info.number } catch (e: Exception) { "抓不到" }

                // countryIso: SIM 卡設定的國家/地區碼 (ISO 代碼)
                val countryIso = try { info.countryIso } catch (e: Exception) { "抓不到" }

                // dataRoaming: 是否開啟數據漫遊 (1=roaming enable, 0=disabled)，也可能抓不到
                val dataRoaming = try { info.dataRoaming } catch (e: Exception) { "抓不到" }

                // isEmbedded: 是否為 eSIM (只在 API 29+ 有效)
                val isEmbedded = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    try { info.isEmbedded } catch (e: Exception) { "抓不到" }
                } else {
                    "抓不到"
                }

                // isOpportunistic: 是否為「機會性」訂閱(某些特殊 SIM)，只在 API 29+ 有效
                val isOpportunistic = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    try { info.isOpportunistic } catch (e: Exception) { "抓不到" }
                } else {
                    "抓不到"
                }

                val map = mapOf(
                    "subscriptionId" to subscriptionId,
                    "slotIndex" to slotIndex,
                    "displayName" to displayName,
                    "carrierName" to carrierName,
                    "iccId" to iccId,
                    "number" to number,
                    "countryIso" to countryIso,
                    "dataRoaming" to dataRoaming,
                    "isEmbedded" to isEmbedded,
                    "isOpportunistic" to isOpportunistic
                )
                simInfoList.add(map)
            }
        }

        return simInfoList
    }
}
