# Shared LiteLLM model catalog.
#
# Single source of truth for the public models served by the LiteLLM proxy on
# the VPS. Consumed by:
#   - modules/services/litellm  -> generates model_list + fallback chain
#   - modules/apps/opencode     -> generates the litellm provider models
#
# Add a model here and both the proxy and opencode pick it up automatically.
{
  # Number of upstream OpenCode API keys to rotate through per tier.
  keyCount = 4;

  # Public models. Each entry:
  #   alias       – public model name clients call (e.g. "flash")
  #   displayName – name shown in opencode's model picker
  #   tiers       – ordered upstream routes. The first tier is primary; later
  #                 tiers are only used as fallbacks. Each tier fans out over
  #                 `keyCount` keys, so a failed/exhausted key falls through to
  #                 the next one. Tier names distinguish variants in fallbacks.
  #                 `api` selects the upstream base URL from vps.litellm options.
  models = [
    {
      alias = "flash";
      displayName = "LiteLLM Flash";
      tiers = [
        {
          name = "free";
          model = "openai/deepseek-v4-flash-free";
          api = "zen";
        }
        {
          name = "paid";
          model = "openai/deepseek-v4-flash";
          api = "go";
        }
      ];
    }
    {
      alias = "normal";
      displayName = "LiteLLM Normal";
      tiers = [
        {
          name = "normal";
          model = "openai/deepseek-v4-pro";
          api = "go";
        }
      ];
    }
  ];
}
