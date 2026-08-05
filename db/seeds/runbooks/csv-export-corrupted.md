---
runbook_id: csv-export-corrupted
owner: "@ghbfs-tech"
last_updated: "2026-02-11"
title: "CSV export downloads corrupted or shows garbled characters"
symptoms:
  - "Schools report the downloaded CSV shows £ or accented characters as garbage"
  - "Opening the CSV in Excel produces cells split across the wrong columns"
  - "Sentry shows encoding errors from the CsvExporter service"
---

## General guidance

Our CSV exports are UTF-8 encoded with a BOM (Byte Order Mark) to keep
Excel happy. If the BOM is missing, Excel interprets £ and accented
characters as ISO-8859-1 and displays garbage. If the delimiter
detection is wrong for the school's locale, cells split incorrectly.

## Pre-requisites

- Access to the `@ghbfs-tech` GitHub team
- `kubectl` configured against the `ghbfs-production` AKS namespace
- A copy of the corrupted CSV the school received (for diagnosis)

## Steps

### 1. Diagnose the encoding

Ask the affected user to send you the CSV. Check:

```
file the-file.csv
head -c 3 the-file.csv | xxd
```

If the first three bytes are not `ef bb bf`, the BOM is missing.

### 2. Confirm the CsvExporter config

```
kubectl exec -n ghbfs-production deploy/ghbfs-web -- bundle exec rails runner 'puts CsvExporter.config.inspect'
```

Expected output: `encoding: UTF-8, bom: true, delimiter: ','`.

### 3. Reset the exporter defaults

If configuration has drifted:

```
kubectl exec -n ghbfs-production deploy/ghbfs-web -- bundle exec rails csv:reset_defaults
```

### 4. Regenerate the export

```
kubectl exec -n ghbfs-production deploy/ghbfs-web -- bundle exec rails exports:regenerate[<export_id>]
```

The `export_id` is visible in the URL when the school hits the
"Download" button; ask them to send it.

## Verification

Ask the school to download the regenerated file and open it in Excel.
Confirm £ and accented characters display correctly and column
boundaries are respected.

## Escalation

If encoding was correct all along, the issue is likely on the school's
end (e.g. they opened the CSV in a locale-specific version of Excel).
Advise them to use "Data → Import from Text" with UTF-8 selected. No
tech escalation needed in that case.
