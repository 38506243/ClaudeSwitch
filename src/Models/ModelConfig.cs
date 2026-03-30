using System;

namespace ClaudeSwitch.Models;

public class ModelConfig
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Name { get; set; } = "";
    public string BaseUrl { get; set; } = "";
    public string ApiToken { get; set; } = "";
    public string ModelId { get; set; } = "";
    public bool IsActive { get; set; } = false;
}
