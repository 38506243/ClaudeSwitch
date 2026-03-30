using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using ClaudeSwitch.Models;

namespace ClaudeSwitch.Services;

public static class ConfigService
{
    private static readonly string ClaudeDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".claude");
    private static readonly string ModelsFile = Path.Combine(ClaudeDir, "model-switcher", "models.json");
    private static readonly string SettingsFile = Path.Combine(ClaudeDir, "settings.json");

    public static List<ModelConfig> LoadModels()
    {
        try
        {
            if (File.Exists(ModelsFile))
            {
                var json = File.ReadAllText(ModelsFile);
                return JsonSerializer.Deserialize<List<ModelConfig>>(json) ?? new List<ModelConfig>();
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"加载模型配置失败: {ex.Message}");
        }
        return new List<ModelConfig>();
    }

    public static void SaveModels(List<ModelConfig> models)
    {
        try
        {
            var dir = Path.GetDirectoryName(ModelsFile);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                Directory.CreateDirectory(dir);

            var json = JsonSerializer.Serialize(models, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(ModelsFile, json);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"保存模型配置失败: {ex.Message}");
        }
    }

    public static void ApplyModel(ModelConfig model)
    {
        try
        {
            var settings = new Dictionary<string, object>
            {
                { "env", new Dictionary<string, string>
                    {
                        { "ANTHROPIC_BASE_URL", model.BaseUrl },
                        { "ANTHROPIC_AUTH_TOKEN", model.ApiToken },
                        { "ANTHROPIC_MODEL", model.ModelId },
                        { "API_TIMEOUT_MS", "300000" },
                        { "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC", "1" }
                    }
                }
            };

            var json = JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(SettingsFile, json);

            // 更新 models.json 中的激活状态
            var models = LoadModels();
            foreach (var m in models)
                m.IsActive = (m.Id == model.Id);
            SaveModels(models);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"应用模型配置失败: {ex.Message}");
        }
    }

    public static ModelConfig? GetActiveModel()
    {
        var models = LoadModels();
        foreach (var m in models)
            if (m.IsActive) return m;
        return models.Count > 0 ? models[0] : null;
    }
}
