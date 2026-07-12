# Writing rules

Applies to human-facing prose: blog posts, essays, long-form articles, technical docs,
READMEs, reports. Not code, code comments, commit messages, or chat replies. When the task is
clearly one of these prose forms, follow these rules.

## Style

- British English (optimise, behaviour, colour, modelling, normalise, analyse). Yield only to
  an explicit house style that mandates US spelling.
- No em dash. Use a plain dash "-". (Also enforced globally.)
- Parentheticals sparingly. A short aside is fine; if the point matters, fold it into the
  sentence; never stack or over-use them.
  - AVOID: The port (which took a week and taught me a lot about scan) was worth it.
  - OK: JAX (via nn.scan) unrolls the loop.

## Clarity

- One term per concept. Pick a name and use it everywhere; never use two words for the same
  thing, and never reuse one word for two different things.
  - BAD: ...the data-misfit... later ...the data mismatch...
  - GOOD: data mismatch throughout
- Keep distinct concepts distinctly named. If two ideas sound alike, name them so a reader can
  never conflate them, and keep each idea's discussion in one place.
- Define an abbreviation once, at first use, then use it consistently. Don't abbreviate where
  the full word reads fine.
- Place references and links at the end of the sentence or clause they support, not mid-sentence
  after a name or term.
  - BAD: Higuchi et al. [1] show that the reset stabilises training.
  - GOOD: The smooth reset stabilises training [1].

## Structure and voice (adjacent - not from the thesis, added in the same taste)

- Lead with the point. Conclusion first, then support; don't bury it under setup.
- Prefer active voice. "The port cut training to 33s", not "training was cut to 33s".
- Cut filler. Drop "very", "in order to", "really", "just", and words that carry no information.
- One idea per paragraph. Start a new paragraph when the point changes.

## Deliberately not rules here

- Lists: allowed freely wherever they read well.
- Numeric precision: no rounding mandate; use the precision the content needs.
