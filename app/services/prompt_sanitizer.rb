# Redacts obvious secrets and PII from incident text before it goes to Claude.
# Belt-and-braces defence — incident reports from support tickets can carry
# stack traces, log snippets, or copy-pasted auth headers with real API keys.
module PromptSanitizer
  PATTERNS = {
    "[REDACTED_ANTHROPIC_KEY]" => /sk-ant-[A-Za-z0-9_\-]{20,}/,
    "[REDACTED_OPENAI_KEY]"    => /\bsk-[A-Za-z0-9]{20,}\b/,
    "[REDACTED_AWS_KEY]"       => /\bAKIA[0-9A-Z]{16}\b/,
    "[REDACTED_BEARER]"        => /Bearer\s+\S{20,}/,
    "[REDACTED_EMAIL]"         => /\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b/
  }.freeze

  def self.sanitize(text)
    return text if text.blank?

    result = text.dup
    PATTERNS.each { |replacement, pattern| result.gsub!(pattern, replacement) }
    result
  end
end
