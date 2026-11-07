using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;

namespace PlanDeCuentasSetup
{
    internal static class Program
    {
        public static string InstallDir => Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Programs",
            "Plan de Cuentas"
        );

        public static string StartMenuFolder => Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.Programs),
            "Plan de Cuentas"
        );

        public static string DesktopShortcut => Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
            "Plan de Cuentas.lnk"
        );

        private const string UninstallRegKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\PlanDeCuentas";

        [STAThread]
        static int Main(string[] args)
        {
            ApplicationConfiguration.Initialize();

            bool isSilent = false;
            bool isUninstall = false;
            bool launchAfter = false;

            foreach (var a in args)
            {
                if (a.Equals("--silent", StringComparison.OrdinalIgnoreCase) ||
                    a.Equals("/S", StringComparison.OrdinalIgnoreCase))
                {
                    isSilent = true;
                }
                else if (a.Equals("--uninstall", StringComparison.OrdinalIgnoreCase))
                {
                    isUninstall = true;
                }
                else if (a.Equals("--launch", StringComparison.OrdinalIgnoreCase))
                {
                    launchAfter = true;
                }
            }

            if (isUninstall)
            {
                PerformUninstall(isSilent);
                return 0;
            }

            if (isSilent)
            {
                PerformInstall(createStartMenu: true, createDesktop: true, launchApp: launchAfter);
                return 0;
            }

            Application.Run(new SetupForm());
            return 0;
        }

        public static void PerformInstall(bool createStartMenu, bool createDesktop, bool launchApp)
        {
            // Close running instances of PlanDeCuentas if any
            foreach (var proc in Process.GetProcessesByName("PlanDeCuentas"))
            {
                if (proc.Id == Environment.ProcessId) continue;
                try { proc.Kill(); proc.WaitForExit(2000); } catch { }
            }

            Directory.CreateDirectory(InstallDir);

            using Stream? stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip");
            if (stream == null)
            {
                throw new InvalidOperationException("No se encontró el paquete integrado payload.zip.");
            }

            string tempZip = Path.Combine(Path.GetTempPath(), "plancuentas_payload_" + Guid.NewGuid().ToString("N") + ".zip");
            using (var fs = File.Create(tempZip))
            {
                stream.CopyTo(fs);
            }

            ZipFile.ExtractToDirectory(tempZip, InstallDir, overwriteFiles: true);
            try { File.Delete(tempZip); } catch { }

            string exePath = Path.Combine(InstallDir, "PlanDeCuentas.exe");
            string iconPath = Path.Combine(InstallDir, "app_icon.ico");
            string uninstallerPath = Path.Combine(InstallDir, "Uninstall.exe");

            try
            {
                string currentExe = Environment.ProcessPath ?? Application.ExecutablePath;
                if (!string.IsNullOrEmpty(currentExe) && File.Exists(currentExe))
                {
                    File.Copy(currentExe, uninstallerPath, overwrite: true);
                }
            }
            catch { }

            if (createStartMenu)
            {
                Directory.CreateDirectory(StartMenuFolder);
                CreateShortcut(
                    shortcutPath: Path.Combine(StartMenuFolder, "Plan de Cuentas.lnk"),
                    targetPath: exePath,
                    workingDir: InstallDir,
                    description: "Plan de Cuentas - Suite Modular de Finanzas Personales",
                    iconLocation: iconPath,
                    arguments: ""
                );
                CreateShortcut(
                    shortcutPath: Path.Combine(StartMenuFolder, "Desinstalar Plan de Cuentas.lnk"),
                    targetPath: uninstallerPath,
                    workingDir: InstallDir,
                    description: "Desinstalar Plan de Cuentas",
                    iconLocation: iconPath,
                    arguments: "--uninstall"
                );
            }

            if (createDesktop)
            {
                CreateShortcut(
                    shortcutPath: DesktopShortcut,
                    targetPath: exePath,
                    workingDir: InstallDir,
                    description: "Plan de Cuentas - Suite Modular de Finanzas Personales",
                    iconLocation: iconPath,
                    arguments: ""
                );
            }

            // Register in Windows Installed Apps (Add/Remove Programs)
            using (RegistryKey key = Registry.CurrentUser.CreateSubKey(UninstallRegKey))
            {
                key.SetValue("DisplayName", "Plan de Cuentas");
                key.SetValue("DisplayVersion", "2.0.0");
                key.SetValue("Publisher", "Plan de Cuentas");
                key.SetValue("DisplayIcon", iconPath);
                key.SetValue("InstallLocation", InstallDir);
                key.SetValue("UninstallString", $"\"{uninstallerPath}\" --uninstall");
                key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
            }

            if (launchApp && File.Exists(exePath))
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = exePath,
                    WorkingDirectory = InstallDir,
                    UseShellExecute = true
                });
            }
        }

        public static void PerformUninstall(bool silent)
        {
            if (!silent)
            {
                var confirm = MessageBox.Show(
                    "¿Deseas desinstalar Plan de Cuentas de tu computadora?",
                    "Desinstalar Plan de Cuentas",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Question
                );
                if (confirm != DialogResult.Yes) return;
            }

            foreach (var proc in Process.GetProcessesByName("PlanDeCuentas"))
            {
                if (proc.Id == Environment.ProcessId) continue;
                try { proc.Kill(); proc.WaitForExit(2000); } catch { }
            }

            try
            {
                if (Directory.Exists(StartMenuFolder))
                {
                    Directory.Delete(StartMenuFolder, recursive: true);
                }
            }
            catch { }

            try
            {
                if (File.Exists(DesktopShortcut))
                {
                    File.Delete(DesktopShortcut);
                }
            }
            catch { }

            try
            {
                Registry.CurrentUser.DeleteSubKeyTree(UninstallRegKey, throwOnMissingSubKey: false);
            }
            catch { }

            // Schedule self-deletion of InstallDir via cmd
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = $"/C timeout /t 2 /nobreak > NUL & rmdir /s /q \"{InstallDir}\"",
                    CreateNoWindow = true,
                    UseShellExecute = false
                });
            }
            catch { }

            if (!silent)
            {
                MessageBox.Show(
                    "Plan de Cuentas se ha desinstalado correctamente.",
                    "Plan de Cuentas",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information
                );
            }
        }

        private static void CreateShortcut(
            string shortcutPath,
            string targetPath,
            string workingDir,
            string description,
            string iconLocation,
            string arguments)
        {
            try
            {
                Type? shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType == null) return;
                dynamic? shell = Activator.CreateInstance(shellType);
                if (shell == null) return;
                dynamic shortcut = shell.CreateShortcut(shortcutPath);
                shortcut.TargetPath = targetPath;
                shortcut.WorkingDirectory = workingDir;
                shortcut.Description = description;
                if (!string.IsNullOrEmpty(arguments))
                {
                    shortcut.Arguments = arguments;
                }
                if (!string.IsNullOrEmpty(iconLocation) && File.Exists(iconLocation))
                {
                    shortcut.IconLocation = iconLocation + ",0";
                }
                shortcut.Save();
            }
            catch { }
        }
    }

    public class SetupForm : Form
    {
        private readonly CheckBox _chkStartMenu;
        private readonly CheckBox _chkDesktop;
        private readonly CheckBox _chkLaunch;
        private readonly Button _btnInstall;
        private readonly ProgressBar _progress;
        private readonly Label _lblStatus;

        public SetupForm()
        {
            Text = "Instalador de Plan de Cuentas v2.0";
            Size = new Size(520, 410);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Color.FromArgb(15, 23, 42);
            ForeColor = Color.White;

            try
            {
                Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            }
            catch { }

            var lblTitle = new Label
            {
                Text = "Plan de Cuentas (Escritorio)",
                Font = new Font("Segoe UI", 16, FontStyle.Bold),
                ForeColor = Color.FromArgb(45, 212, 191),
                Location = new Point(28, 24),
                AutoSize = true
            };

            var lblSub = new Label
            {
                Text = "Instala la aplicación en tu PC con acceso exclusivo por QR,\ncarpeta en Todos los programas e indexación en Windows.",
                Font = new Font("Segoe UI", 9.5f, FontStyle.Regular),
                ForeColor = Color.FromArgb(203, 213, 225),
                Location = new Point(28, 62),
                Size = new Size(450, 44)
            };

            var lblPath = new Label
            {
                Text = "Ruta: " + Program.InstallDir,
                Font = new Font("Segoe UI", 8.5f, FontStyle.Regular),
                ForeColor = Color.FromArgb(148, 163, 184),
                Location = new Point(28, 112),
                Size = new Size(450, 22)
            };

            _chkStartMenu = new CheckBox
            {
                Text = "Crear carpeta en 'Todos los programas' e indexar en Búsqueda",
                Checked = true,
                Font = new Font("Segoe UI", 9.5f),
                ForeColor = Color.White,
                Location = new Point(30, 148),
                Size = new Size(450, 26)
            };

            _chkDesktop = new CheckBox
            {
                Text = "Crear acceso directo en el Escritorio",
                Checked = true,
                Font = new Font("Segoe UI", 9.5f),
                ForeColor = Color.White,
                Location = new Point(30, 180),
                Size = new Size(450, 26)
            };

            _chkLaunch = new CheckBox
            {
                Text = "Abrir Plan de Cuentas al finalizar la instalación",
                Checked = true,
                Font = new Font("Segoe UI", 9.5f),
                ForeColor = Color.White,
                Location = new Point(30, 212),
                Size = new Size(450, 26)
            };

            _progress = new ProgressBar
            {
                Location = new Point(28, 258),
                Size = new Size(446, 18),
                Style = ProgressBarStyle.Blocks,
                Value = 0
            };

            _lblStatus = new Label
            {
                Text = "Listo para instalar.",
                Font = new Font("Segoe UI", 9f),
                ForeColor = Color.FromArgb(148, 163, 184),
                Location = new Point(28, 282),
                Size = new Size(446, 22)
            };

            _btnInstall = new Button
            {
                Text = "Instalar ahora",
                Font = new Font("Segoe UI", 10.5f, FontStyle.Bold),
                BackColor = Color.FromArgb(13, 148, 136),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Location = new Point(314, 314),
                Size = new Size(160, 40),
                Cursor = Cursors.Hand
            };
            _btnInstall.FlatAppearance.BorderSize = 0;
            _btnInstall.Click += OnInstallClick;

            Controls.AddRange(new Control[]
            {
                lblTitle, lblSub, lblPath,
                _chkStartMenu, _chkDesktop, _chkLaunch,
                _progress, _lblStatus, _btnInstall
            });
        }

        private void OnInstallClick(object? sender, EventArgs e)
        {
            try
            {
                _btnInstall.Enabled = false;
                _progress.Value = 30;
                _lblStatus.Text = "Instalando archivos y creando accesos directos...";
                Application.DoEvents();

                Program.PerformInstall(
                    createStartMenu: _chkStartMenu.Checked,
                    createDesktop: _chkDesktop.Checked,
                    launchApp: _chkLaunch.Checked
                );

                _progress.Value = 100;
                _lblStatus.Text = "¡Instalación completada con éxito!";
                MessageBox.Show(
                    "Plan de Cuentas se ha instalado correctamente en tu computadora.\n\n" +
                    "• Menú Inicio: Todos los programas -> Plan de Cuentas\n" +
                    "• Escritorio: Acceso directo creado",
                    "Instalación Completada",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information
                );
                Close();
            }
            catch (Exception ex)
            {
                _btnInstall.Enabled = true;
                MessageBox.Show(
                    "Error durante la instalación:\n" + ex.Message,
                    "Error",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
            }
        }
    }
}
