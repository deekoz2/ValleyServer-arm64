package com.deekoz2.valleyserver;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * 接收 Termux / ZeroTermux RUN_COMMAND 的执行结果回执。
 *
 * Termux 在命令执行完毕后，会向安装时传入的 PendingIntent 发送广播，
 * 携带以下 extras：
 *   - com.termux.RUN_COMMAND_RESULT : int  退出码
 *   - com.termux.RUN_COMMAND_STDOUT : String
 *   - com.termux.RUN_COMMAND_STDERR : String
 */
public class ResultReceiver extends BroadcastReceiver {

    public interface Callback {
        void onResult(int idx, int code, String stdout, String stderr);
    }

    public static Callback cb;

    @Override
    public void onReceive(Context context, Intent intent) {
        if (cb == null) {
            return;
        }
        cb.onResult(
                intent.getIntExtra("idx", -1),
                intent.getIntExtra("com.termux.RUN_COMMAND_RESULT", -999),
                intent.getStringExtra("com.termux.RUN_COMMAND_STDOUT"),
                intent.getStringExtra("com.termux.RUN_COMMAND_STDERR"));
    }
}
