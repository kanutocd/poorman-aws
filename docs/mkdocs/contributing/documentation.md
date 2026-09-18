# Contribute documentation

Create or update documentation in the same change as the implementation it
describes. Write for a consumer operator or contributor who does not have the
author's local context.

1. Read the relevant implementation, tests, workflows, and existing docs.
2. Put public site content under `docs/mkdocs/`; keep `README.md` focused on first
   contact and navigation.
3. Use action-first procedures with explicit prerequisites and expected results.
4. Keep secrets, populated environment files, state, plans, and provider
   responses out of examples.
5. Preview the site locally with `bin/docs serve`.
6. Run `bin/docs build --strict` before submitting the change.
7. Run the relevant Vale, Markdownlint, and offline Lychee checks when their
   tools are installed.

Use fenced `mermaid` blocks for diagrams. The site configuration maps these
fences to Zensical's Mermaid integration, so do not paste generated SVG or add
a page-specific Mermaid script.

The build output is generated in `site/` and must not be committed. Keep
implementation plans and local harness notes under ignored paths; they are not
public site content.
