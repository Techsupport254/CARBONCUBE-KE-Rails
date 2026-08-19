# Backend (Rails) notes

## Linting

Rubocop is configured (`.rubocop.yml`, plugins: rubocop-rails, rubocop-performance,
rubocop-rspec). Run it with:

```
bundle exec rubocop            # check
bundle exec rubocop -a         # autocorrect safe offenses
bundle exec rubocop -A         # autocorrect including unsafe offenses (review diffs!)
```

`.rubocop_todo.yml` holds a baseline of pre-existing offenses from when Rubocop was
introduced, so existing code doesn't need a mass rewrite. Don't add new entries to it -
new/changed code should be Rubocop-clean. As files in the todo list get cleaned up,
remove their entries.

Run `bundle exec rubocop <path>` to lint just the files you touched before committing.
