package com.example.vidbunkertest

import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView

class VideoNativeAdFactory(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        val adView = NativeAdView(context)
        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 18, 24, 18)
            setBackgroundColor(Color.WHITE)
        }
        val sponsored = TextView(context).apply {
            text = "Sponsored · Ad"
            textSize = 11f
            setTextColor(Color.DKGRAY)
        }
        val headline = TextView(context).apply {
            textSize = 17f
            setTextColor(Color.BLACK)
            setPadding(0, 8, 0, 4)
        }
        headline.text = nativeAd.headline ?: "Recommended for you"
        adView.headlineView = headline
        container.addView(sponsored)
        container.addView(headline)

        nativeAd.body?.let { bodyText ->
            val body = TextView(context).apply {
                text = bodyText
                textSize = 13f
                setTextColor(Color.DKGRAY)
                setPadding(0, 0, 0, 8)
            }
            adView.bodyView = body
            container.addView(body)
        }
        nativeAd.callToAction?.let { actionText ->
            val button = Button(context).apply { text = actionText }
            adView.callToActionView = button
            container.addView(button)
        }
        adView.addView(container)
        adView.setNativeAd(nativeAd)
        return adView
    }
}
