{ colors }:
{
  "$schema" =
    "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";

  name = "flexoki";

  vars = {
    bg0 = colors.bg0;
    bg1 = colors.bg1;
    bg2 = colors.bg2;

    fg0 = colors.fg0;
    fg1 = colors.fg1;
    fg2 = colors.fg2;

    red = colors.redBright;
    green = colors.greenBright;
    yellow = colors.yellowBright;
    blue = colors.blueBright;
    magenta = colors.magentaBright;
    cyan = colors.cyanBright;
    orange = colors.orangeBright;
    purple = colors.purple;
  };

  colors = {
    accent = "orange";
    border = "fg2";
    borderAccent = "orange";
    borderMuted = "fg2";
    success = "green";
    error = "red";
    warning = "yellow";
    muted = "fg1";
    dim = "fg2";
    text = "fg0";
    thinkingText = "fg1";

    selectedBg = "bg2";
    scrollbarThumb = "fg2";
    searchMatchBg = "yellow";
    searchMatchText = "bg0";

    userMessageBg = "bg1";
    userMessageText = "fg0";

    customMessageBg = "bg1";
    customMessageText = "fg0";
    customMessageLabel = "cyan";

    toolPendingBg = "bg1";
    toolSuccessBg = "bg1";
    toolErrorBg = "bg1";
    toolTitle = "blue";
    toolOutput = "fg0";

    mdHeading = "orange";
    mdLink = "blue";
    mdLinkUrl = "fg1";
    mdCode = "cyan";
    mdCodeBlock = "fg0";
    mdCodeBlockBorder = "fg2";
    mdQuote = "fg1";
    mdQuoteBorder = "fg2";
    mdHr = "fg2";
    mdListBullet = "orange";

    toolDiffAdded = "green";
    toolDiffRemoved = "red";
    toolDiffContext = "fg1";

    syntaxComment = "fg1";
    syntaxKeyword = "magenta";
    syntaxFunction = "blue";
    syntaxVariable = "yellow";
    syntaxString = "green";
    syntaxNumber = "purple";
    syntaxType = "cyan";
    syntaxOperator = "orange";
    syntaxPunctuation = "fg1";

    thinkingOff = "fg2";
    thinkingMinimal = "fg1";
    thinkingLow = "blue";
    thinkingMedium = "cyan";
    thinkingHigh = "magenta";
    thinkingXhigh = "red";
    thinkingMax = "orange";

    bashMode = "yellow";
  };
}
