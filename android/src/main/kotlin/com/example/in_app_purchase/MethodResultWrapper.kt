package com.dooboolab.flutterinapppurchase

import android.os.Handler
import io.flutter.plugin.common.MethodChannel
import java.lang.Runnable
import android.os.Looper

// MethodChannel.Result wrapper that responds on the platform thread.
class MethodResultWrapper internal constructor(
    private val safeResult: MethodChannel.Result,
    private val safeChannel: MethodChannel
) : MethodChannel.Result {
    private val handler: Handler = Handler(Looper.getMainLooper())
    override fun success(result: Any?) {
        handler.postDelayed({ safeResult.success(result) },50)
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        handler.postDelayed({ safeResult.error(errorCode, errorMessage, errorDetails)},50)
    }

    override fun notImplemented() {
        handler.postDelayed({ safeResult.notImplemented() },50)
    }

    fun invokeMethod(method: String?, arguments: Any?) {
        handler.postDelayed({ safeChannel.invokeMethod(method!!, arguments, null) },50)
    }

}