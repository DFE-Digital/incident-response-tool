"""
Build the 6-slide overview deck for the incident-response-tool.

Deliberately hand-drawn shapes rather than external image files — the
resulting .pptx is self-contained and editable slide-by-slide in
PowerPoint / Google Slides / LibreOffice Impress.

Run:  python3 docs/build_deck.py
Out:  docs/incident-response-tool.pptx
"""

from pathlib import Path
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE, MSO_CONNECTOR
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR

# --- palette (GOV.UK-inspired) --------------------------------------
GOVUK_BLUE   = RGBColor(0x1D, 0x70, 0xB8)
GOVUK_BLACK  = RGBColor(0x0B, 0x0C, 0x0C)
GOVUK_GREY   = RGBColor(0x50, 0x5A, 0x5F)
GOVUK_LIGHT  = RGBColor(0xF3, 0xF2, 0xF1)
GOVUK_GREEN  = RGBColor(0x00, 0x70, 0x3C)
GOVUK_YELLOW = RGBColor(0xFF, 0xDD, 0x00)
GOVUK_RED    = RGBColor(0xD4, 0x35, 0x1C)
WHITE        = RGBColor(0xFF, 0xFF, 0xFF)


def new_deck():
    prs = Presentation()
    prs.slide_width  = Inches(13.333)
    prs.slide_height = Inches(7.5)
    return prs


def blank_slide(prs):
    return prs.slides.add_slide(prs.slide_layouts[6])  # blank


def add_text(slide, x, y, w, h, text, *, size=18, bold=False, color=GOVUK_BLACK,
             align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP):
    tb = slide.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    tf.margin_left = tf.margin_right = Emu(0)
    tf.margin_top = tf.margin_bottom = Emu(0)
    lines = text.split("\n") if isinstance(text, str) else text
    for i, line in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = align
        run = p.add_run()
        run.text = line
        run.font.size = Pt(size)
        run.font.bold = bold
        run.font.color.rgb = color
        run.font.name = "Calibri"
    return tb


def add_bullets(slide, x, y, w, h, items, *, size=18, color=GOVUK_BLACK):
    tb = slide.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = Emu(0)
    for i, item in enumerate(items):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.space_after = Pt(8)
        run = p.add_run()
        run.text = "• " + item
        run.font.size = Pt(size)
        run.font.color.rgb = color
        run.font.name = "Calibri"
    return tb


def add_box(slide, x, y, w, h, text, *, fill=GOVUK_BLUE, text_color=WHITE,
            size=14, bold=True, align=PP_ALIGN.CENTER):
    shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x, y, w, h)
    shape.fill.solid()
    shape.fill.fore_color.rgb = fill
    shape.line.color.rgb = fill
    tf = shape.text_frame
    tf.margin_left = tf.margin_right = Inches(0.1)
    tf.margin_top = tf.margin_bottom = Inches(0.05)
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.alignment = align
    run = p.add_run()
    run.text = text
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = text_color
    run.font.name = "Calibri"
    return shape


def add_arrow(slide, x1, y1, x2, y2, *, color=GOVUK_GREY, weight=2.0):
    c = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, x1, y1, x2, y2)
    c.line.color.rgb = color
    c.line.width = Pt(weight)
    # Add arrow head
    from pptx.oxml.ns import qn
    from lxml import etree
    ln = c.line._get_or_add_ln()
    tail = etree.SubElement(ln, qn("a:tailEnd"))
    tail.set("type", "triangle")
    tail.set("w", "med")
    tail.set("h", "med")
    return c


def add_footer(slide, prs, page, total):
    add_text(slide, Inches(0.5), prs.slide_height - Inches(0.4),
             Inches(6), Inches(0.3),
             "Incident Response Tool  ·  DfE  ·  W12 hackathon",
             size=10, color=GOVUK_GREY)
    add_text(slide, prs.slide_width - Inches(1.5),
             prs.slide_height - Inches(0.4),
             Inches(1), Inches(0.3),
             f"{page} / {total}",
             size=10, color=GOVUK_GREY, align=PP_ALIGN.RIGHT)


def title_bar(slide, prs, text):
    # Left-aligned title bar
    add_box(slide, Inches(0.5), Inches(0.4), Inches(12.3), Inches(0.7),
            text, fill=GOVUK_BLUE, size=24, align=PP_ALIGN.LEFT)


# --------------------------------------------------------------------
# Slide 1 — Title
# --------------------------------------------------------------------
def slide_1(prs):
    s = blank_slide(prs)

    # Big colour block on the left
    band = s.shapes.add_shape(MSO_SHAPE.RECTANGLE,
                              0, 0, Inches(4), prs.slide_height)
    band.fill.solid()
    band.fill.fore_color.rgb = GOVUK_BLUE
    band.line.fill.background()

    add_text(s, Inches(0.5), Inches(0.6), Inches(3), Inches(0.4),
             "DfE", size=14, bold=True, color=WHITE)
    add_text(s, Inches(0.5), Inches(1.0), Inches(3), Inches(0.4),
             "W12 hackathon", size=12, color=WHITE)

    add_text(s, Inches(4.5), Inches(2.0), Inches(8.3), Inches(1.5),
             "Incident Response Tool",
             size=48, bold=True, color=GOVUK_BLACK)
    add_text(s, Inches(4.5), Inches(3.4), Inches(8.3), Inches(0.8),
             "An AI-assisted incident lifecycle for DfE digital services",
             size=22, color=GOVUK_GREY)

    add_text(s, Inches(4.5), Inches(5.0), Inches(8.3), Inches(0.4),
             "Three artefacts.  One incident thread.  No vector DB.",
             size=16, bold=True, color=GOVUK_BLUE)

    add_text(s, Inches(4.5), Inches(6.4), Inches(8.3), Inches(0.4),
             "David Feetenby  ·  Serena Abbott  ·  and one Claude",
             size=12, color=GOVUK_GREY)


# --------------------------------------------------------------------
# Slide 2 — The problem
# --------------------------------------------------------------------
def slide_2(prs):
    s = blank_slide(prs)
    title_bar(s, prs, "The problem on-callers actually have")

    add_bullets(s, Inches(0.7), Inches(1.5), Inches(12), Inches(4),
                [
                    "On-callers reconstruct incident context from scratch every time — "
                    "no shared shape for what to capture.",
                    "Runbook discovery is slow when someone else wrote the runbook, "
                    "and half the runbooks aren't written down anyway.",
                    "Post-incident reviews get rushed or skipped — the DfE template "
                    "is good but empty templates don't fill themselves in.",
                    "Facts (severity, timeline, decisions) get separated from the "
                    "meeting where they're needed.",
                    "Every artefact ends up copy-pasted into Teams by hand, which "
                    "is where the real work actually happens.",
                ], size=20)

    # Callout box
    add_box(s, Inches(0.7), Inches(5.7), Inches(12), Inches(0.9),
            "The AI value-add isn't 'answer questions from a corpus'.  It's "
            "'reduce toil around a process the humans already run'.",
            fill=GOVUK_LIGHT, text_color=GOVUK_BLACK,
            size=16, bold=True, align=PP_ALIGN.LEFT)

    add_footer(s, prs, 2, 6)


# --------------------------------------------------------------------
# Slide 3 — What we built (architecture diagram)
# --------------------------------------------------------------------
def slide_3(prs):
    s = blank_slide(prs)
    title_bar(s, prs, "Three artefacts, one incident thread")

    y = Inches(1.7)

    # Left: intake
    add_box(s, Inches(0.4), y, Inches(2.2), Inches(1.0),
            "Incident intake\n(GOV.UK form)", fill=GOVUK_GREY, size=14)

    # Middle: Rails + Claude
    add_box(s, Inches(3.0), y, Inches(3.0), Inches(1.0),
            "Rails 6.1  +  Claude Opus 4.7\n(prompt-cached corpus)",
            fill=GOVUK_BLUE, size=14)

    # Right column: three artefacts
    ax = Inches(6.4)
    aw = Inches(3.2)
    ah = Inches(0.65)
    add_box(s, ax, Inches(1.35), aw, ah,
            "🔧  Process artefact",
            fill=GOVUK_GREEN, size=13)
    add_box(s, ax, Inches(2.10), aw, ah,
            "📖  Runbook artefact (retrieved / drafted / refused)",
            fill=GOVUK_GREEN, size=13)
    add_box(s, ax, Inches(2.85), aw, ah,
            "✅  Post-incident review",
            fill=GOVUK_GREEN, size=13)

    # Rightmost: Teams
    add_box(s, Inches(9.9), y, Inches(2.9), Inches(1.0),
            "Teams channel\n(Adaptive Cards)", fill=GOVUK_GREY, size=14)

    # Arrows
    add_arrow(s, Inches(2.6), Inches(2.2),  Inches(3.0), Inches(2.2))
    add_arrow(s, Inches(6.0), Inches(2.2),  Inches(6.4), Inches(2.2))
    add_arrow(s, Inches(9.6), Inches(2.2),  Inches(9.9), Inches(2.2))

    # Bottom text — data flow
    add_text(s, Inches(0.7), Inches(3.5), Inches(12), Inches(0.5),
             "Each event fires an Adaptive Card into the incident's Teams thread.",
             size=14, color=GOVUK_GREY)

    # Layer of guarantees
    add_text(s, Inches(0.7), Inches(4.2), Inches(12), Inches(0.4),
             "Guarantees per Claude call:",
             size=16, bold=True, color=GOVUK_BLACK)
    add_bullets(s, Inches(0.9), Inches(4.7), Inches(12), Inches(2),
                [
                    "Structured JSON output — no free-form prose to parse.",
                    "Corpus is synthetic + in git — no PII exposure.",
                    "PromptSanitizer redacts API keys and emails before Claude sees them.",
                    "Refuses non-operational reports rather than inventing.",
                    "Every call records token usage + cache-hit rate for cost visibility.",
                ], size=14, color=GOVUK_BLACK)

    add_footer(s, prs, 3, 6)


# --------------------------------------------------------------------
# Slide 4 — CAG vs RAG
# --------------------------------------------------------------------
def slide_4(prs):
    s = blank_slide(prs)
    title_bar(s, prs, "The architectural bet: Cache-Augmented Generation")

    # Two columns
    col_w = Inches(6.0)
    col_h = Inches(4.2)
    top   = Inches(1.6)

    # RAG column (left, muted)
    rag = s.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE,
                              Inches(0.5), top, col_w, col_h)
    rag.fill.solid(); rag.fill.fore_color.rgb = GOVUK_LIGHT
    rag.line.color.rgb = GOVUK_GREY
    add_text(s, Inches(0.7), Inches(1.75), Inches(5.5), Inches(0.5),
             "RAG (what most people build)",
             size=18, bold=True, color=GOVUK_GREY)
    add_bullets(s, Inches(0.9), Inches(2.4), Inches(5.5), Inches(3),
                [
                    "Vector DB stores embedded chunks",
                    "Embedding model turns query → vector",
                    "Similarity search narrows the corpus",
                    "Retrieved chunks stuffed into context",
                    "Chunk boundaries + threshold tuning matter",
                ], size=14, color=GOVUK_GREY)

    # CAG column (right, highlighted)
    cag = s.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE,
                              Inches(6.9), top, col_w, col_h)
    cag.fill.solid(); cag.fill.fore_color.rgb = GOVUK_BLUE
    cag.line.color.rgb = GOVUK_BLUE
    add_text(s, Inches(7.1), Inches(1.75), Inches(5.5), Inches(0.5),
             "CAG (what we built)",
             size=18, bold=True, color=WHITE)
    add_bullets(s, Inches(7.3), Inches(2.4), Inches(5.5), Inches(3),
                [
                    "Whole ~5k-token corpus in the system prompt",
                    "Anthropic prompt cache → ~10× cheaper reads",
                    "Retrieval = LLM attention over the full context",
                    "Zero infrastructure: no DB, no embedder, no chunker",
                    "Live cache-hit rate visible in the UI (≥95% typical)",
                ], size=14, color=WHITE)

    # Pull quote below
    add_box(s, Inches(0.5), Inches(6.0), Inches(12.4), Inches(0.9),
            "\"Attack surface is one third party: Anthropic. "
            "RAG would add two more — the embedding vendor and the vector DB.\"",
            fill=GOVUK_BLACK, text_color=WHITE,
            size=16, bold=False, align=PP_ALIGN.CENTER)

    add_footer(s, prs, 4, 6)


# --------------------------------------------------------------------
# Slide 5 — Guardrails + observability
# --------------------------------------------------------------------
def slide_5(prs):
    s = blank_slide(prs)
    title_bar(s, prs, "Safety, cost, evidence")

    top = Inches(1.6)
    card_w = Inches(4.05)
    card_h = Inches(4.6)

    # Three cards
    def card(x, colour, title, items):
        box = s.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE,
                                  x, top, card_w, card_h)
        box.fill.solid(); box.fill.fore_color.rgb = WHITE
        box.line.color.rgb = colour
        box.line.width = Pt(2.5)
        # Coloured title band
        band = s.shapes.add_shape(MSO_SHAPE.RECTANGLE,
                                  x, top, card_w, Inches(0.7))
        band.fill.solid(); band.fill.fore_color.rgb = colour
        band.line.fill.background()
        add_text(s, x + Inches(0.15), top + Inches(0.15),
                 card_w - Inches(0.3), Inches(0.4),
                 title, size=17, bold=True, color=WHITE)
        add_bullets(s, x + Inches(0.2), top + Inches(0.9),
                    card_w - Inches(0.4), card_h - Inches(1.0),
                    items, size=13, color=GOVUK_BLACK)

    card(Inches(0.4), GOVUK_GREEN, "Guardrails", [
        "PromptSanitizer redacts API keys, Bearer tokens and emails "
        "before every Claude call.",
        "Length caps: title ≤200, description ≤10 000 chars.",
        "Refuse-over-invent — non-operational reports get an "
        "honest 'no runbook covers this' banner.",
        "Blameless voice enforced in the review prompt.",
    ])

    card(Inches(4.65), GOVUK_BLUE, "Cost visibility", [
        "Every artefact stores input / cache-creation / cache-read / "
        "output tokens.",
        "AnthropicPricing.summary_line renders per-artefact:",
        "   \"10 996 tokens · $0.06 · 100% cache hit\"",
        "Cache-hit rate is a live proof that CAG is behaving.",
    ])

    card(Inches(8.9), GOVUK_RED, "Evidence", [
        "spec/evals — 10 curated scenarios in three buckets: "
        "retrieval, draft, refuse.",
        "bundle exec rake eval:runbook prints a scorecard against "
        "real Claude calls.",
        "Full run: 10/10 pass, 0 hallucinations, ~$0.96 total.",
        "Wrapped in a transaction so test data doesn't persist.",
    ])

    add_footer(s, prs, 5, 6)


# --------------------------------------------------------------------
# Slide 6 — What shipped / results
# --------------------------------------------------------------------
def slide_6(prs):
    s = blank_slide(prs)
    title_bar(s, prs, "What shipped")

    # Left half: shipped list
    add_text(s, Inches(0.6), Inches(1.5), Inches(6), Inches(0.4),
             "Sprint outcome", size=20, bold=True, color=GOVUK_BLACK)
    add_bullets(s, Inches(0.6), Inches(2.0), Inches(6.5), Inches(4.5),
                [
                    "Step 1 — Incident intake form (GDS formbuilder)",
                    "Step 2 — Process artefact (severity + actions)",
                    "Step 3 — Runbook artefact (retrieved/drafted/refused)",
                    "Step 4 — Post-incident review (fill-in-the-blanks template)",
                    "Step 5 — Teams integration (Adaptive Cards)",
                    "Step 6 — Incidents dashboard + filters",
                    "Step 7 — Guardrails, cost panel, eval harness",
                    "Stretch S3 — ISO 42001 compliance mapping",
                ], size=16, color=GOVUK_BLACK)

    # Right half: numbers
    add_text(s, Inches(7.5), Inches(1.5), Inches(5.4), Inches(0.4),
             "By the numbers", size=20, bold=True, color=GOVUK_BLACK)

    def stat(x, y, big, small, colour=GOVUK_BLUE):
        add_text(s, x, y, Inches(2.6), Inches(0.9),
                 big, size=44, bold=True, color=colour)
        add_text(s, x, y + Inches(0.85), Inches(2.6), Inches(0.4),
                 small, size=12, color=GOVUK_GREY)

    stat(Inches(7.5), Inches(2.1), "10/10", "eval scenarios passed")
    stat(Inches(10.3), Inches(2.1), "0", "hallucinated runbook_ids", GOVUK_GREEN)
    stat(Inches(7.5), Inches(3.5), "~95%", "cache-hit rate on runbooks")
    stat(Inches(10.3), Inches(3.5), "~$0.06", "cost per full incident")
    stat(Inches(7.5), Inches(4.9), "3", "artefacts per incident", GOVUK_GREY)
    stat(Inches(10.3), Inches(4.9), "0", "vector DBs deployed", GOVUK_RED)

    # Footer strip: what's next
    add_box(s, Inches(0.5), Inches(6.4), Inches(12.4), Inches(0.7),
            "Next: live Teams via M365 dev tenant  ·  larger eval set  ·  "
            "aggregate cost dashboard  ·  MCP / Slack bolt-ons",
            fill=GOVUK_LIGHT, text_color=GOVUK_BLACK,
            size=13, bold=False, align=PP_ALIGN.CENTER)

    add_footer(s, prs, 6, 6)


# --------------------------------------------------------------------
def main():
    prs = new_deck()
    slide_1(prs)
    slide_2(prs)
    slide_3(prs)
    slide_4(prs)
    slide_5(prs)
    slide_6(prs)
    out = Path(__file__).parent / "incident-response-tool.pptx"
    prs.save(out)
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
