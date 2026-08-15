# Project record mirrors

One directory per project generated from this template, named after its
repository, holding that project's records copied **verbatim**:

    docs/projects/<repo>/escapes.md
    docs/projects/<repo>/DECISIONS.md
    docs/projects/<repo>/BACKLOG.md
    docs/projects/<repo>/GLOSSARY.project.md

## Why this exists

Most defects a project logs are the *template's* — things only the template can
fix. `docs/escapes.md` here records the check that answers each one, and a check
is only as good as the evidence behind it. Before this directory, that evidence
lived in another repository, so an entry here either re-narrated an incident
(and drifted from the original) or pointed at a file nobody reading this
repository could open.

Mirroring the records solves that, and buys one more thing: with many projects
it stays visible **which project produced which evidence**. A gate that keeps
failing in the same way across three projects is a different signal from one
that failed once, and that comparison is only possible if the sources are here
and separable.

## The rules

- **Copied, not moved.** The originating project keeps its own records. Its log
  is the incident record of what happened *there*, it is append-only, and
  nothing is deleted from it. No pointer is written back down either — a
  bookkeeping line about an upstream copy is not an incident.
- **Verbatim.** These files are not edited here. Editing a mirror makes it stop
  being evidence and start being a second opinion. Refresh by re-copying.
- **`GLOSSARY.project.md` is the one exception to "nothing is deleted"**, and by
  design rather than by special case. It exists only because a project session
  may not have this repository attached, so it is the only place an agent can
  add a word mid-project — a staging buffer, not a record. Its words are merged
  into `template/GLOSSARY.md.jinja` here, and the project's copy is then wiped
  back to empty; the words return to every project on the next template update.
  There are deliberately no lasting project-specific glossaries.

  Sequence the wipe with the update that carries the words back down. Wiping
  first leaves the project with no definitions in between.

## When there are many

Not a problem yet, and deferred by owner ruling until it is. What to do about
hundreds of long logs — trimming, indexing, summarising — is a decision to make
against a real corpus rather than in advance of one.
