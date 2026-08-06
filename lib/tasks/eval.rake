namespace :eval do
  desc "Run the runbook artefact eval scenarios against real Claude calls"
  task runbook: :environment do
    require "yaml"

    scenarios = YAML.load_file(Rails.root.join("spec/evals/runbook_scenarios.yml"))
    corpus_ids = RunbookCorpus.runbook_ids

    results = { retrieval: [], draft: [], refuse: [] }
    hallucinations = []
    total_cost = 0.0

    puts "Running #{scenarios.length} scenarios against #{ClaudeRunbookService::MODEL}...\n\n"

    ActiveRecord::Base.transaction do
      scenarios.each do |s|
        incident = Incident.create!(
          title: s.fetch("title"),
          description: s.fetch("description"),
          service: s.fetch("service"),
          status: "open"
        )

        artefact = ClaudeRunbookService.new(incident).call
        total_cost += AnthropicPricing.summarise(artefact)[:total_cost_usd]

        # Hallucination check: if a runbook_id is returned it must be a real corpus id.
        if artefact.runbook_id.present? && !corpus_ids.include?(artefact.runbook_id)
          hallucinations << { scenario: s["id"], invented_id: artefact.runbook_id }
        end

        bucket  = s.fetch("bucket").to_sym
        passed  = case bucket
                  when :retrieval
                    artefact.match_type == "retrieved" && artefact.runbook_id == s["expected_runbook_id"]
                  when :draft
                    artefact.match_type == "drafted"
                  when :refuse
                    artefact.match_type == "refused"
                  end

        results[bucket] << {
          id:       s["id"],
          passed:   passed,
          expected: bucket == :retrieval ? s["expected_runbook_id"] : nil,
          got:      "#{artefact.match_type}#{artefact.runbook_id ? " (#{artefact.runbook_id})" : ""}"
        }

        mark = passed ? "✓" : "✗"
        puts "  #{mark} [#{bucket}] #{s["id"]}: #{artefact.match_type}#{artefact.runbook_id ? " → #{artefact.runbook_id}" : ""}"
      end

      raise ActiveRecord::Rollback
    end

    puts "\n" + "=" * 60
    puts "Scorecard"
    puts "=" * 60

    thresholds = { retrieval: 85, draft: 85, refuse: 90 }

    [:retrieval, :draft, :refuse].each do |bucket|
      passes = results[bucket].count { |r| r[:passed] }
      total  = results[bucket].length
      pct    = total.zero? ? 0 : (passes.to_f / total * 100).round(1)
      status = pct >= thresholds[bucket] ? "PASS" : "FAIL"
      puts "  #{bucket.to_s.ljust(11)}: #{passes}/#{total} (#{pct}%)  threshold #{thresholds[bucket]}%  [#{status}]"

      results[bucket].reject { |r| r[:passed] }.each do |r|
        expected = r[:expected] ? " (expected #{r[:expected]})" : ""
        puts "    ✗ #{r[:id]} — got #{r[:got]}#{expected}"
      end
    end

    puts ""
    if hallucinations.empty?
      puts "  hallucinations: 0    [PASS]"
    else
      puts "  hallucinations: #{hallucinations.length}    [FAIL]"
      hallucinations.each { |h| puts "    ✗ #{h[:scenario]} — invented #{h[:invented_id]}" }
    end

    puts ""
    puts "  total Claude cost: $%.4f" % total_cost
    puts ""
  end
end
