# Identify persistent viewed entries by resolved comparison

Viewed state is scoped to a repository and its resolved revision pair, while each entry is identified by change kind and path. Resolving refs prevents marks from leaking into new commits when a branch moves, and including the change kind keeps staged, working, and conflicting diffs separate; path filters are excluded because they are only narrower windows onto the same comparison.
