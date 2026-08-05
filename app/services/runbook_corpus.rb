class RunbookCorpus
  CORPUS_DIR = Rails.root.join("db/seeds/runbooks").freeze

  def self.formatted_for_prompt
    entries = Dir.glob(CORPUS_DIR.join("*.md")).sort.map do |path|
      "---\n# Runbook: #{File.basename(path, ".md")}\n---\n\n#{File.read(path)}"
    end

    <<~PROMPT
      The following is the complete corpus of GHBfS operational runbooks
      available to you. Each runbook has YAML frontmatter with an ID,
      owner, last-updated date, and symptoms, followed by the runbook body.

      There are #{entries.count} runbooks in the corpus. Use them literally —
      do not invent runbooks or steps that are not in the corpus.

      ===== RUNBOOK CORPUS BEGINS =====

      #{entries.join("\n\n")}

      ===== RUNBOOK CORPUS ENDS =====
    PROMPT
  end

  def self.runbook_ids
    Dir.glob(CORPUS_DIR.join("*.md")).map { |p| File.basename(p, ".md") }.sort
  end
end
