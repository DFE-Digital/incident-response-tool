# Cost calculation for Claude Opus 4.7 usage.
# Rates in USD per million tokens (as of Aug 2026).
module AnthropicPricing
  RATES_PER_MILLION_USD = {
    input:          15.00,
    cache_creation: 18.75,   # ~25% more than input
    cache_read:      1.50,   # 10x cheaper than input
    output:         75.00
  }.freeze

  # artefact: any record with the four usage columns.
  # Returns a hash: { input, cache_creation, cache_read, output, total, cache_hit_rate }.
  def self.summarise(artefact)
    input          = artefact.input_tokens.to_i
    cache_creation = artefact.cache_creation_input_tokens.to_i
    cache_read     = artefact.cache_read_input_tokens.to_i
    output         = artefact.output_tokens.to_i

    costs = {
      input:          input          * RATES_PER_MILLION_USD[:input]          / 1_000_000.0,
      cache_creation: cache_creation * RATES_PER_MILLION_USD[:cache_creation] / 1_000_000.0,
      cache_read:     cache_read     * RATES_PER_MILLION_USD[:cache_read]     / 1_000_000.0,
      output:         output         * RATES_PER_MILLION_USD[:output]         / 1_000_000.0
    }

    total_input_tokens = input + cache_creation + cache_read
    cache_hit_rate = total_input_tokens.zero? ? nil : (cache_read.to_f / total_input_tokens)

    {
      input_tokens:          input,
      cache_creation_tokens: cache_creation,
      cache_read_tokens:     cache_read,
      output_tokens:         output,
      total_tokens:          total_input_tokens + output,
      total_cost_usd:        costs.values.sum,
      cache_hit_rate:        cache_hit_rate
    }
  end

  # Format a summary as a compact one-line string for UI display.
  def self.summary_line(artefact)
    s = summarise(artefact)
    return nil if s[:total_tokens].zero?

    parts = [
      "#{s[:total_tokens]} tokens",
      "$%.4f" % s[:total_cost_usd]
    ]
    parts << "#{(s[:cache_hit_rate] * 100).round}% cache hit" if s[:cache_hit_rate]&.positive?
    parts.join(" · ")
  end
end
