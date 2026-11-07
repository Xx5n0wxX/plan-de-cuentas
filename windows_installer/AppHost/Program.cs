using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace PlanDeCuentasDesktop
{
    internal static class Program
    {
        [STAThread]
        static void Main()
        {
            ApplicationConfiguration.Initialize();
            Application.Run(new MainForm());
        }
    }

    public class MainForm : Form
    {
        private readonly WebView2 _webView;
        private HttpListener? _server;
        private CancellationTokenSource? _cts;
        private int _port = 45670;

        [DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

        private static readonly Dictionary<string, string> MimeTypes = new(StringComparer.OrdinalIgnoreCase)
        {
            { ".html", "text/html; charset=utf-8" },
            { ".js", "application/javascript; charset=utf-8" },
            { ".mjs", "application/javascript; charset=utf-8" },
            { ".json", "application/json; charset=utf-8" },
            { ".css", "text/css; charset=utf-8" },
            { ".png", "image/png" },
            { ".jpg", "image/jpeg" },
            { ".jpeg", "image/jpeg" },
            { ".gif", "image/gif" },
            { ".svg", "image/svg+xml" },
            { ".ico", "image/x-icon" },
            { ".wasm", "application/wasm" },
            { ".otf", "font/otf" },
            { ".ttf", "font/ttf" },
            { ".woff", "font/woff" },
            { ".woff2", "font/woff2" },
            { ".frag", "application/octet-stream" }
        };

        public MainForm()
        {
            Text = "Plan de Cuentas";
            Size = new Size(1280, 820);
            MinimumSize = new Size(920, 660);
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Color.FromArgb(15, 23, 42);

            try
            {
                string iconPath = Path.Combine(AppContext.BaseDirectory, "app_icon.ico");
                if (File.Exists(iconPath))
                {
                    Icon = new Icon(iconPath);
                }
                else
                {
                    Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
                }
            }
            catch { }

            try
            {
                int useDarkMode = 1;
                DwmSetWindowAttribute(Handle, 20, ref useDarkMode, sizeof(int));
            }
            catch { }

            _webView = new WebView2
            {
                Dock = DockStyle.Fill,
                DefaultBackgroundColor = Color.FromArgb(15, 23, 42)
            };
            Controls.Add(_webView);

            Load += async (_, _) => await InitializeDesktopAppAsync();
            FormClosing += (_, _) => StopLocalServer();
        }

        private async Task InitializeDesktopAppAsync()
        {
            string webRoot = Path.Combine(AppContext.BaseDirectory, "data", "web");
            if (!Directory.Exists(webRoot))
            {
                MessageBox.Show(
                    "No se encontraron los archivos de datos de la aplicación en:\n" + webRoot,
                    "Plan de Cuentas",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
                Close();
                return;
            }

            StartLocalServer(webRoot);

            string userDataDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "PlanDeCuentas",
                "DesktopProfile"
            );
            Directory.CreateDirectory(userDataDir);

            var env = await CoreWebView2Environment.CreateAsync(null, userDataDir);
            await _webView.EnsureCoreWebView2Async(env);

            var settings = _webView.CoreWebView2.Settings;
            settings.AreDefaultContextMenusEnabled = false;
            settings.IsStatusBarEnabled = false;
            settings.AreDevToolsEnabled = false;
            settings.IsZoomControlEnabled = false;

            // Enforce strict QR-only session on Desktop: any non-linked session is purged automatically
            await _webView.CoreWebView2.AddScriptToExecuteOnDocumentCreatedAsync(@"
                (function() {
                    try {
                        var raw = window.localStorage.getItem('flutter.app_user_session');
                        if (raw) {
                            var parsed = JSON.parse(raw);
                            if (typeof parsed === 'string') {
                                parsed = JSON.parse(parsed);
                            }
                            if (!parsed || parsed.isLinkedDesktop !== true) {
                                window.localStorage.removeItem('flutter.app_user_session');
                            }
                        }
                    } catch (e) {}
                })();
            ");

            bool cloudReachable = await CheckCloudOnlineAsync();
            if (cloudReachable)
            {
                long ts = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
                _webView.CoreWebView2.Navigate($"https://plan-de-cuentas-45670.web.app/?desktop=1&v={ts}");
            }
            else
            {
                _webView.CoreWebView2.Navigate($"http://127.0.0.1:{_port}/");
            }
        }

        private static async Task<bool> CheckCloudOnlineAsync()
        {
            try
            {
                using var http = new System.Net.Http.HttpClient
                {
                    Timeout = TimeSpan.FromSeconds(3)
                };
                using var resp = await http.GetAsync("https://plan-de-cuentas-45670.web.app/version.json");
                return resp.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        private void StartLocalServer(string webRoot)
        {
            int[] candidatePorts = new[] { 45670, 45671, 45672, 45673 };
            foreach (int p in candidatePorts)
            {
                try
                {
                    var listener = new HttpListener();
                    listener.Prefixes.Add($"http://127.0.0.1:{p}/");
                    listener.Start();
                    _server = listener;
                    _port = p;
                    break;
                }
                catch
                {
                    // Try next port
                }
            }

            if (_server == null)
            {
                // Fallback to ephemeral port
                var tcp = new TcpListener(IPAddress.Loopback, 0);
                tcp.Start();
                _port = ((IPEndPoint)tcp.LocalEndpoint).Port;
                tcp.Stop();

                _server = new HttpListener();
                _server.Prefixes.Add($"http://127.0.0.1:{_port}/");
                _server.Start();
            }

            _cts = new CancellationTokenSource();
            var token = _cts.Token;

            Task.Run(async () =>
            {
                while (!token.IsCancellationRequested && _server != null && _server.IsListening)
                {
                    try
                    {
                        var ctx = await _server.GetContextAsync();
                        _ = Task.Run(() => HandleRequest(ctx, webRoot), token);
                    }
                    catch
                    {
                        break;
                    }
                }
            }, token);
        }

        private static void HandleRequest(HttpListenerContext ctx, string webRoot)
        {
            try
            {
                string urlPath = Uri.UnescapeDataString(ctx.Request.Url?.AbsolutePath ?? "/");
                if (urlPath == "/" || string.IsNullOrWhiteSpace(urlPath))
                {
                    urlPath = "/index.html";
                }

                string relativePath = urlPath.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
                string fullPath = Path.GetFullPath(Path.Combine(webRoot, relativePath));

                if (!fullPath.StartsWith(Path.GetFullPath(webRoot), StringComparison.OrdinalIgnoreCase) ||
                    !File.Exists(fullPath))
                {
                    fullPath = Path.Combine(webRoot, "index.html");
                }

                string ext = Path.GetExtension(fullPath);
                ctx.Response.ContentType = MimeTypes.TryGetValue(ext, out var mime)
                    ? mime
                    : "application/octet-stream";
                ctx.Response.Headers["Cache-Control"] = "no-cache";

                byte[] bytes = File.ReadAllBytes(fullPath);
                ctx.Response.ContentLength64 = bytes.Length;
                ctx.Response.OutputStream.Write(bytes, 0, bytes.Length);
                ctx.Response.OutputStream.Close();
            }
            catch
            {
                try { ctx.Response.Abort(); } catch { }
            }
        }

        private void StopLocalServer()
        {
            try
            {
                _cts?.Cancel();
                _server?.Stop();
                _server?.Close();
            }
            catch { }
        }
    }
}
