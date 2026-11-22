package com.deekoz2.valleyserver;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

/**
 * 星露谷开服器 —— ValleyServer-arm64 的 Android 前端。
 *
 * 功能：
 *  1. 检测 Termux / ZeroTermux 是否安装；
 *  2. 通过 Termux RUN_COMMAND 发送测试命令，验证 APP 能否连通 Termux/ZeroTermux；
 *  3. 一键安装：在 Termux 里执行仓库的 install.sh（tmoe 容器 + ValleyServer）。
 */
public class MainActivity extends Activity implements ResultReceiver.Callback {

    static final String ACTION_RUN_COMMAND = "com.termux.RUN_COMMAND";
    static final String EXTRA_PATH = "com.termux.RUN_COMMAND_PATH";
    static final String EXTRA_ARGS = "com.termux.RUN_COMMAND_ARGUMENTS";
    static final String EXTRA_BG = "com.termux.RUN_COMMAND_BACKGROUND";
    static final String EXTRA_PI = "com.termux.RUN_COMMAND_PENDING_INTENT";
    /** PendingIntent.FLAG_MUTABLE 的数值（编译用 API 30 jar，故用字面量） */
    static final int FLAG_MUTABLE = 0x02000000;

    static final String[] TARGETS = { "com.termux", "com.zerotermux" };
    static final String[] LABELS = { "Termux", "ZeroTermux" };
    static final long TEST_TIMEOUT_MS = 12000;

    static final String INSTALL_URL =
            "https://raw.githubusercontent.com/deekoz2/ValleyServer-arm64/main/install.sh";
    static final String INSTALL_CMD =
            "apt update -y; apt install -y curl; curl -fsSL " + INSTALL_URL
                    + " -o ~/valley-install.sh && bash ~/valley-install.sh";

    Handler ui;
    TextView logView;
    ScrollView logScroll;
    TextView[] statusViews = new TextView[2];
    boolean[] waiting = new boolean[2];

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ui = new Handler(Looper.getMainLooper());
        ResultReceiver.cb = this;
        setContentView(buildUi());
        refreshStatus();
    }

    @Override
    protected void onDestroy() {
        ResultReceiver.cb = null;
        super.onDestroy();
    }

    /* ---------------- 界面 ---------------- */

    View buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(0xFF0B1220);
        root.setPadding(dp(20), dp(24), dp(20), dp(16));

        root.addView(text("星露谷开服器", 22, 0xFFF8FAFC, Typeface.BOLD));
        root.addView(text("ValleyServer-arm64 · 无头专用服务器（无需游戏本体）", 12, 0xFF94A3B8, Typeface.NORMAL));
        root.addView(gap(14));

        for (int i = 0; i < TARGETS.length; i++) {
            LinearLayout card = card();
            card.addView(text(LABELS[i], 15, 0xFFE2E8F0, Typeface.BOLD));
            statusViews[i] = text("检测中…", 12, 0xFF94A3B8, Typeface.NORMAL);
            card.addView(statusViews[i]);
            root.addView(card);
            root.addView(gap(10));
        }
        root.addView(gap(4));

        root.addView(button("1. 检测能否连接 Termux / ZeroTermux", 0xFF166534, new View.OnClickListener() {
            @Override public void onClick(View v) { testConnection(); }
        }));
        root.addView(gap(10));
        root.addView(button("2. 一键安装开服环境", 0xFF9A3412, new View.OnClickListener() {
            @Override public void onClick(View v) { oneClickInstall(); }
        }));
        root.addView(gap(10));
        root.addView(button("使用说明", 0xFF334155, new View.OnClickListener() {
            @Override public void onClick(View v) { showHelp(); }
        }));

        root.addView(gap(14));
        root.addView(text("运行日志", 13, 0xFFCBD5E1, Typeface.BOLD));
        root.addView(gap(6));
        logScroll = new ScrollView(this);
        logView = new TextView(this);
        logView.setTypeface(Typeface.MONOSPACE);
        logView.setTextSize(11);
        logView.setTextColor(0xFFA7F3D0);
        logView.setText("就绪。先检测连接，再一键安装。\n");
        logScroll.addView(logView);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f);
        logScroll.setLayoutParams(lp);
        root.addView(logScroll);
        return root;
    }

    TextView text(String s, int sp, int color, int style) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextSize(sp);
        t.setTextColor(color);
        t.setTypeface(Typeface.DEFAULT, style);
        return t;
    }

    LinearLayout gap(int h) {
        LinearLayout v = new LinearLayout(this);
        v.setLayoutParams(new LinearLayout.LayoutParams(1, dp(h)));
        return v;
    }

    LinearLayout card() {
        LinearLayout c = new LinearLayout(this);
        c.setOrientation(LinearLayout.VERTICAL);
        c.setPadding(dp(14), dp(12), dp(14), dp(12));
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(0xFF121B2C);
        bg.setCornerRadius(dp(14));
        c.setBackground(bg);
        return c;
    }

    Button button(String label, int color, View.OnClickListener l) {
        Button b = new Button(this);
        b.setText(label);
        b.setAllCaps(false);
        b.setTextColor(0xFFFFFFFF);
        b.setTextSize(14);
        b.setPadding(dp(14), dp(12), dp(14), dp(12));
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(color);
        bg.setCornerRadius(dp(12));
        b.setBackground(bg);
        b.setOnClickListener(l);
        return b;
    }

    int dp(int d) {
        return (int) (d * getResources().getDisplayMetrics().density);
    }

    /* ---------------- 状态检测（第 1 层） ---------------- */

    void refreshStatus() {
        for (int i = 0; i < TARGETS.length; i++) {
            statusViews[i].setText(describe(TARGETS[i]));
        }
    }

    String describe(String pkg) {
        try {
            PackageInfo pi = getPackageManager().getPackageInfo(pkg, 0);
            String v = pi.versionName == null ? "?" : pi.versionName;
            return "已安装 · v" + v + "  —  可点「检测连接」验证";
        } catch (PackageManager.NameNotFoundException e) {
            return "未安装（请先安装 Termux 或 ZeroTermux）";
        }
    }

    boolean installed(String pkg) {
        try {
            getPackageManager().getPackageInfo(pkg, 0);
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        }
    }

    /* ---------------- 连接测试（第 2 层） ---------------- */

    void testConnection() {
        boolean any = false;
        for (int i = 0; i < TARGETS.length; i++) {
            if (!installed(TARGETS[i])) {
                continue;
            }
            any = true;
            waiting[i] = true;
            boolean ok = sendCommand(TARGETS[i],
                    new String[] { "-c", "echo valley-ok" }, getPi(i), true);
            if (ok) {
                log("→ 已向 " + LABELS[i] + " 发送测试命令，等待回执（最长 " + (TEST_TIMEOUT_MS / 1000) + " 秒）…");
                armTimeout(i);
            } else {
                waiting[i] = false;
            }
        }
        if (!any) {
            log("✗ 未检测到 Termux / ZeroTermux，请先安装其中一个。");
        }
    }

    void armTimeout(final int i) {
        ui.postDelayed(new Runnable() {
            @Override public void run() {
                if (!waiting[i]) {
                    return;
                }
                waiting[i] = false;
                log("✗ " + LABELS[i] + " " + (TEST_TIMEOUT_MS / 1000) + " 秒无回执。排查：");
                log("   1) Termux 侧需允许外部应用：~/.termux/termux.properties 里加 allow-external-apps=true 后重启 Termux");
                log("   2) 保持 Termux 可后台运行（关闭电池优化 / 加白名单）");
                log("   3) ZeroTermux 若不支持 RUN_COMMAND，请改用原版 Termux");
            }
        }, TEST_TIMEOUT_MS);
    }

    @Override
    public void onResult(final int idx, final int code, final String stdout, final String stderr) {
        ui.post(new Runnable() {
            @Override public void run() {
                if (idx < 0 || idx >= TARGETS.length || !waiting[idx]) {
                    return;
                }
                waiting[idx] = false;
                if (code == 0 && stdout != null && stdout.contains("valley-ok")) {
                    log("✓ 连接成功：" + LABELS[idx] + " 可正常执行命令，可以一键安装了！");
                } else {
                    log("⚠ " + LABELS[idx] + " 有回执但异常：code=" + code
                            + (stderr == null ? "" : "  stderr=" + stderr.trim()));
                }
            }
        });
    }

    /* ---------------- 一键安装 ---------------- */

    void oneClickInstall() {
        for (int i = 0; i < TARGETS.length; i++) {
            if (!installed(TARGETS[i])) {
                continue;
            }
            boolean ok = sendCommand(TARGETS[i], new String[] { "-c", INSTALL_CMD }, null, true);
            if (ok) {
                log("→ 已把一键安装脚本发往 " + LABELS[i] + "。请打开 Termux 看进度：");
                log("   脚本会调用 tmoe 创建 proot 容器（在 tmoe 菜单里选 Debian → arm64 → proot），");
                log("   然后下载 ValleyServer v3.0.3 linux-arm64（约 448MB）并部署。");
                log("   装完在 Termux 里输入 valley 启动服务器（默认端口 24642/udp）。");
                return;
            }
        }
        log("✗ 未检测到 Termux / ZeroTermux，无法一键安装。");
    }

    void showHelp() {
        log("── 使用说明 ──────────────────────────");
        log("1. 手机安装 Termux 或 ZeroTermux，打开一次并允许存储权限；");
        log("2. 点「检测连接」：本 APP 会通过系统 intent 调起 Termux 执行一条");
        log("   测试命令并等待回执，验证链路是否通畅；");
        log("3. 点「一键安装」：在 Termux 里执行 install.sh（使用 tmoe 创建");
        log("   proot 容器，部署 ValleyServer 无头服务器）；");
        log("4. 启动：Termux 里输入 valley（前台）或 valley start（后台）；");
        log("5. 联机：同一 Wi-Fi 下好友填 你的IP:24642 ；外网联机需内网穿透");
        log("   （frp / Tailscale 等）。");
        log("服务器本体: Lixeer/ValleyServer v3.0.3 (Apache-2.0)，本仓库为");
        log("linux-arm64 DSH 修复版。Apache-2.0 © deekoz2");
        log("──────────────────────────────────────");
    }

    /* ---------------- RUN_COMMAND 发送 ---------------- */

    PendingIntent getPi(int idx) {
        Intent i = new Intent("com.deekoz2.valleyserver.RESULT");
        i.setPackage(getPackageName());
        i.setComponent(new ComponentName(this, ResultReceiver.class));
        i.putExtra("idx", idx);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 31) {
            flags |= FLAG_MUTABLE;
        }
        return PendingIntent.getBroadcast(this, idx + 1, i, flags);
    }

    boolean sendCommand(String pkg, String[] args, PendingIntent pi, boolean bg) {
        boolean ok = tryStart(buildIntent(pkg, args, pi, bg, true));
        if (!ok) {
            log("… 尝试不指定组件再发一次（兼容 fork 版）");
            ok = tryStart(buildIntent(pkg, args, pi, bg, false));
        }
        return ok;
    }

    Intent buildIntent(String pkg, String[] args, PendingIntent pi, boolean bg, boolean withComponent) {
        Intent i = new Intent(ACTION_RUN_COMMAND);
        i.setPackage(pkg);
        if (withComponent) {
            i.setComponent(new ComponentName(pkg, pkg + ".app.RunCommandService"));
        }
        i.putExtra(EXTRA_PATH, "/data/data/" + pkg + "/files/usr/bin/bash");
        i.putExtra(EXTRA_ARGS, args);
        i.putExtra(EXTRA_BG, bg);
        if (pi != null) {
            i.putExtra(EXTRA_PI, pi);
        }
        return i;
    }

    boolean tryStart(Intent i) {
        try {
            if (Build.VERSION.SDK_INT >= 26) {
                startForegroundService(i);
            } else {
                startService(i);
            }
            return true;
        } catch (Throwable t) {
            log("✗ 无法调起 " + i.getPackage() + "：" + t.getClass().getSimpleName());
            return false;
        }
    }

    /* ---------------- 日志 ---------------- */

    void log(final String s) {
        ui.post(new Runnable() {
            @Override public void run() {
                logView.append(s + "\n");
                logScroll.post(new Runnable() {
                    @Override public void run() {
                        logScroll.fullScroll(View.FOCUS_DOWN);
                    }
                });
            }
        });
    }
}
