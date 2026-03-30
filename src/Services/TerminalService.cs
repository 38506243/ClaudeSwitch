using System;
using System.Diagnostics;
using System.IO;

namespace ClaudeSwitch.Services;

public static class TerminalService
{
    public static bool IsClaudeCodeInstalled()
    {
        try
        {
            var result = RunCommand("which", "claude");
            return result.ExitCode == 0;
        }
        catch
        {
            return false;
        }
    }

    public static void InstallClaudeCode(Action<string>? onOutput = null)
    {
        try
        {
            onOutput?.Invoke("正在安装 Claude Code...\n");
            var result = RunCommand("npm", "install -g @anthropic-ai/claude-code", waitForExit: false, onOutput);
            onOutput?.Invoke($"\n安装完成! 退出码: {result.ExitCode}");
        }
        catch (Exception ex)
        {
            onOutput?.Invoke($"安装失败: {ex.Message}");
        }
    }

    public static void OpenTerminalAndRun(string command = "claude")
    {
        try
        {
            // 先尝试 iTerm2
            if (IsAppInstalled("iTerm2"))
            {
                // AppleScript 创建新窗口并执行命令
                var script = $@"
                    tell application ""iTerm2""
                        activate
                        try
                            create window with default profile
                        on error
                            tell current window
                                create tab with default profile
                            end tell
                        end try
                        tell current session of current window
                            write text ""{command}""
                        end tell
                    end tell
                ";
                RunCommand("osascript", $"-e '{script}'");
                return;
            }

            // 降级到 macOS Terminal
            if (IsAppInstalled("Terminal") || IsAppInstalled("/System/Applications/Utilities/Terminal.app"))
            {
                var script = $@"
                    tell application ""Terminal""
                        activate
                        do script ""{command}""
                    end tell
                ";
                RunCommand("osascript", $"-e '{script}'");
                return;
            }

            Console.WriteLine("未找到可用的终端应用");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"打开终端失败: {ex.Message}");
        }
    }

    private static bool IsAppInstalled(string appName)
    {
        try
        {
            // 尝试直接打开，如果成功就说明安装了
            var result = RunCommand("open", $"-a \"{appName}\" --dry-run");
            return result.ExitCode == 0 || File.Exists($"/Applications/{appName}.app");
        }
        catch
        {
            return false;
        }
    }

    public static (int ExitCode, string Output) RunCommand(string fileName, string arguments, bool waitForExit = true, Action<string>? onOutput = null)
    {
        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = arguments,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            }
        };

        if (!waitForExit)
        {
            process.StartInfo.RedirectStandardOutput = false;
            process.StartInfo.RedirectStandardError = false;
            process.Start();
            return (0, "");
        }

        var output = "";
        process.OutputDataReceived += (s, e) =>
        {
            if (e.Data != null)
            {
                output += e.Data + "\n";
                onOutput?.Invoke(e.Data);
            }
        };
        process.ErrorDataReceived += (s, e) =>
        {
            if (e.Data != null)
                onOutput?.Invoke($"[错误] {e.Data}");
        };

        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        process.WaitForExit();

        return (process.ExitCode, output);
    }
}
