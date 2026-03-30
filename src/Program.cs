using System;
using System.Collections.ObjectModel;
using System.Linq;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using ClaudeSwitch.Models;
using ClaudeSwitch.Services;

namespace ClaudeSwitch;

class Program
{
    static void Main(string[] args)
    {
        BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
    }

    public static AppBuilder BuildAvaloniaApp() =>
        AppBuilder.Configure<App>().UsePlatformDetect();
}

public class ModelItem : ObservableObject
{
    private bool _isActive;
    public bool IsActive
    {
        get => _isActive;
        set => SetAndRaise(ref _isActive, value);
    }

    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string BaseUrl { get; set; } = "";
    public string ApiToken { get; set; } = "";
    public string ModelId { get; set; } = "";
}

public class AddModelWindow : Window
{
    public ModelItem? Result { get; private set; }
    private readonly TextBox _nameBox = new();
    private readonly TextBox _urlBox = new();
    private readonly TextBox _tokenBox = new();
    private readonly TextBox _modelIdBox = new();

    public AddModelWindow()
    {
        Title = "添加模型";
        Width = 380;
        Height = 300;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        CanResize = false;
        Background = new SolidColorBrush(Color.FromRgb(45, 45, 48));

        var grid = new Grid { Margin = new Thickness(20) };
        grid.RowDefinitions.Add(new RowDefinition(GridLength.Auto));
        grid.RowDefinitions.Add(new RowDefinition(GridLength.Auto));
        grid.RowDefinitions.Add(new RowDefinition(GridLength.Auto));
        grid.RowDefinitions.Add(new RowDefinition(GridLength.Auto));
        grid.RowDefinitions.Add(new RowDefinition(GridLength.Auto));
        grid.RowDefinitions.Add(new RowDefinition(GridLength.Auto));
        grid.RowDefinitions.Add(new RowDefinition(GridLength.Auto));

        void AddRow(int row, string label, TextBox box)
        {
            var lbl = new TextBlock { Text = label, Foreground = Brushes.White, Margin = new Thickness(0, 8, 0, 4) };
            Grid.SetRow(lbl, row);
            grid.Children.Add(lbl);
            box.Margin = new Thickness(0, 0, 0, 8);
            Grid.SetRow(box, row + 1);
            grid.Children.Add(box);
        }

        AddRow(0, "模型名称:", _nameBox);
        AddRow(2, "Base URL:", _urlBox);
        AddRow(4, "API Token:", _tokenBox);

        var modelLbl = new TextBlock { Text = "模型 ID:", Foreground = Brushes.White, Margin = new Thickness(0, 8, 0, 4) };
        Grid.SetRow(modelLbl, 6);
        grid.Children.Add(modelLbl);
        Grid.SetRow(_modelIdBox, 7);
        grid.Children.Add(_modelIdBox);

        var btnPanel = new StackPanel
        {
            Orientation = Avalonia.Layout.Orientation.Horizontal,
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right,
            Margin = new Thickness(0, 15, 0, 0)
        };

        var okBtn = new Button { Content = "确定", Width = 90, Margin = new Thickness(0, 0, 10, 0) };
        okBtn.Click += (s, e) =>
        {
            if (string.IsNullOrWhiteSpace(_nameBox.Text) ||
                string.IsNullOrWhiteSpace(_urlBox.Text) ||
                string.IsNullOrWhiteSpace(_tokenBox.Text) ||
                string.IsNullOrWhiteSpace(_modelIdBox.Text))
                return;

            Result = new ModelItem
            {
                Id = Guid.NewGuid().ToString(),
                Name = _nameBox.Text.Trim(),
                BaseUrl = _urlBox.Text.Trim(),
                ApiToken = _tokenBox.Text.Trim(),
                ModelId = _modelIdBox.Text.Trim()
            };
            Close();
        };

        var cancelBtn = new Button { Content = "取消", Width = 90 };
        cancelBtn.Click += (s, e) => Close();

        btnPanel.Children.Add(okBtn);
        btnPanel.Children.Add(cancelBtn);

        var btnContainer = new Border { Child = btnPanel };
        Grid.SetRow(btnContainer, 8);
        grid.Children.Add(btnContainer);

        Content = grid;
    }
}

public class App : Application
{
    private ObservableCollection<ModelItem> _models = new();
    private Window? _mainWindow;

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            desktop.MainWindow = _mainWindow = CreateMainWindow();
            desktop.ShutdownMode = ShutdownMode.OnExplicitShutdown;
        }
        base.OnFrameworkInitializationCompleted();
    }

    private Window CreateMainWindow()
    {
        LoadModels();

        var window = new Window
        {
            Title = "Claude Switch",
            Width = 340,
            Height = 260,
            WindowStartupLocation = WindowStartupLocation.CenterScreen,
            CanResize = false,
            Background = new SolidColorBrush(Color.FromRgb(30, 30, 30)),
            TransparencyLevelHint = new[] { WindowTransparencyLevel.None }
        };

        var panel = new StackPanel { Margin = new Thickness(25) };

        panel.Children.Add(new TextBlock
        {
            Text = "Claude Switch",
            FontSize = 22,
            FontWeight = FontWeight.Bold,
            Foreground = Brushes.White,
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
            Margin = new Thickness(0, 0, 0, 25)
        });

        foreach (var model in _models)
        {
            var btn = new Button
            {
                Content = model.IsActive ? $"  ✔  {model.Name}" : $"     {model.Name}",
                Width = 240,
                Height = 40,
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
                Margin = new Thickness(0, 5),
                Tag = model,
                Background = model.IsActive
                    ? new SolidColorBrush(Color.FromRgb(0, 122, 204))
                    : new SolidColorBrush(Color.FromRgb(60, 60, 60)),
                Foreground = Brushes.White
            };
            btn.Click += OnModelSelected;
            panel.Children.Add(btn);
        }

        var addBtn = new Button
        {
            Content = "  + 添加模型  ",
            Width = 240,
            Height = 38,
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
            Margin = new Thickness(0, 18, 0, 0),
            Background = new SolidColorBrush(Color.FromRgb(50, 50, 50)),
            Foreground = new SolidColorBrush(Color.FromRgb(150, 200, 255))
        };
        addBtn.Click += OnAddModel;
        panel.Children.Add(addBtn);

        window.Content = panel;
        return window;
    }

    private void LoadModels()
    {
        _models.Clear();
        var saved = ConfigService.LoadModels();
        if (saved.Count == 0)
        {
            _models.Add(new ModelItem
            {
                Id = Guid.NewGuid().ToString(),
                Name = "MiniMax",
                BaseUrl = "https://api.minimaxi.com/anthropic",
                ApiToken = "",
                ModelId = "MiniMax-M2.7-highspeed",
                IsActive = true
            });
            SaveModels();
        }
        else
        {
            foreach (var m in saved)
                _models.Add(new ModelItem
                {
                    Id = m.Id, Name = m.Name, BaseUrl = m.BaseUrl,
                    ApiToken = m.ApiToken, ModelId = m.ModelId, IsActive = m.IsActive
                });
        }
    }

    private void SaveModels()
    {
        ConfigService.SaveModels(_models.Select(m => new ModelConfig
        {
            Id = m.Id, Name = m.Name, BaseUrl = m.BaseUrl,
            ApiToken = m.ApiToken, ModelId = m.ModelId, IsActive = m.IsActive
        }).ToList());
    }

    private void OnModelSelected(object? sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is ModelItem model)
        {
            if (!TerminalService.IsClaudeCodeInstalled())
            {
                var installWin = new Window
                {
                    Title = "提示",
                    Width = 320,
                    Height = 150,
                    WindowStartupLocation = WindowStartupLocation.CenterScreen,
                    CanResize = false,
                    Background = new SolidColorBrush(Color.FromRgb(45, 45, 48))
                };

                bool confirmed = false;
                var panel = new StackPanel { Margin = new Thickness(20) };
                panel.Children.Add(new TextBlock
                {
                    Text = "Claude Code 未安装，是否立即安装？",
                    Foreground = Brushes.White,
                    TextWrapping = Avalonia.Media.TextWrapping.Wrap,
                    Margin = new Thickness(0, 0, 0, 20)
                });

                var btnPanel = new StackPanel { Orientation = Avalonia.Layout.Orientation.Horizontal, HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center };
                var yesBtn = new Button { Content = "是", Width = 80, Margin = new Thickness(0, 0, 15, 0) };
                yesBtn.Click += (s, ev) => { confirmed = true; installWin.Close(); };
                var noBtn = new Button { Content = "否", Width = 80 };
                noBtn.Click += (s, ev) => installWin.Close();
                btnPanel.Children.Add(yesBtn);
                btnPanel.Children.Add(noBtn);
                panel.Children.Add(btnPanel);

                installWin.Content = panel;
                installWin.ShowDialog(_mainWindow);

                if (!confirmed) return;
                TerminalService.InstallClaudeCode(msg => Console.WriteLine(msg));
            }

            // 应用配置
            ConfigService.ApplyModel(new ModelConfig
            {
                Id = model.Id, Name = model.Name, BaseUrl = model.BaseUrl,
                ApiToken = model.ApiToken, ModelId = model.ModelId
            });

            // 更新激活状态
            foreach (var m in _models) m.IsActive = (m.Id == model.Id);
            SaveModels();

            // 刷新窗口
            RefreshWindow();

            // 打开终端
            TerminalService.OpenTerminalAndRun("claude");
        }
    }

    private void OnAddModel(object? sender, RoutedEventArgs e)
    {
        var dialog = new AddModelWindow();
        dialog.ShowDialog(_mainWindow);

        if (dialog.Result != null)
        {
            _models.Add(dialog.Result);
            SaveModels();
            RefreshWindow();
        }
    }

    private void RefreshWindow()
    {
        if (_mainWindow == null) return;
        var win = _mainWindow;
        var newWin = CreateMainWindow();
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
            desktop.MainWindow = newWin;
        win.Close();
        _mainWindow = newWin;
        newWin.Show();
    }
}
