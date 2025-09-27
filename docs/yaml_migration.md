# YAML Data Migration Guide

This guide walks through collapsing the legacy per-resource YAML files into the
aggregate bundle consumed by the new exporter/loader pipeline.

## 1. Validate current data

Run the targeted regression tests to ensure exporter previews, seed loading, and
schema validation still pass:

```
bundle exec rails test \
  test/services/yaml_exporter_test.rb \
  test/lib/seeds/loader_apply_test.rb \
  test/lib/yaml_schema_definition_test.rb \
  test/controllers/owner/content_controller_test.rb \
  test/tasks/yaml_collapse_task_test.rb
```

> If Bundler fails with `Could not find 'bundler' (2.6.2)` install it via
> `gem install bundler:2.6.2` (or adjust `Gemfile.lock`) before re-running.

## 2. Dry-run the collapse

Use the new rake task with `DRY_RUN=1` to preview which files would be backed up
and which aggregate file would be written:

```
bundle exec rake yaml:collapse DRY_RUN=1
```

No files are modified during the dry run; the task simply reports the actions it
will take.

## 3. Collapse legacy files

When ready, re-run without `DRY_RUN` to materialize `db/data/aether.yml` and
rename the original YAML files to `*.yml.bak` (including pack resources):

```
bundle exec rake yaml:collapse
```

The aggregate file now contains:

```yaml
core:
  actions:
    - name: "..."
  items:
    - name: "..."
packs:
  forest:
    actions:
      - name: "..."
```

## 4. Export content (aggregate-only)

The owner content screen now always writes to `db/data/aether.yml`. Hitting the
**Export YAML** button updates the aggregate file directly; the per-resource
`*.yml` files are no longer produced.

Automated exports (`YamlExporter.export!` / `export_all!`) now target the same
aggregate file with no additional flags required.

## 5. Rollback

If you need to revert, delete `db/data/aether.yml` and restore the backed-up
files:

```
find db/data -name "*.yml.bak" -exec bash -c 'mv "$0" "${0%.bak}"' {} \;
```

Re-run the validations from step 1 to confirm the system still bootstraps from
the restored files.
