# PantryPal API

Base URL: `http://<backend laptop's IPv4>:8000` (Android emulator: `http://10.0.2.2:8000`).
Live, clickable docs for every endpoint: `<base URL>/docs`.

Every endpoint has a real example response in [`pantrypal/assets/mock/`](../assets/mock/), taken from
the demo store on the demo date (2024-06-20). Regenerate them with `python export_mocks.py`.

Dates are `YYYY-MM-DD` strings. Quantities are in the product's `unit`. Money is RM.
Use dates and `days_left` from the API rather than the phone's clock: the demo runs on 2024-06-20.

## Endpoints

| Screen | Call | Mock file |
|---|---|---|
| Header date | `GET /today` | `today.json` |
| Today's Alerts | `GET /alerts` | `alerts.json` |
| Stock / Batches | `GET /batches` | `batches.json` |
| Stock totals | `GET /stock` | `stock.json` |
| Add Stock: product picker | `GET /products` | `products.json` |
| Add Stock: save | `POST /batches` | `batch_created.json` |
| Batch detail: edit quantity, mark sold out or discarded | `PATCH /batches/{id}` | same shape as `batch_created.json` |
| Delete a batch | `DELETE /batches/{id}` | none (204) |
| Sales import: preview | `POST /sales/import?dry_run=true` | `sales_import_preview.json` |
| Sales import: import valid rows | `POST /sales/import` | `sales_import_done.json` |
| Import history | `GET /sales/imports` | `sales_imports.json` |

### `GET /alerts`
Optional `?today=YYYY-MM-DD` to look at another day. Returns the summary tiles and the alert list:

```json
{"today": "2024-06-20", "expired_or_today": 6, "due_soon": 2, "total_rm_at_risk": 1571.66,
 "total_expected_rm_saved": 67.73, "monitoring": 3, "alerts": [ ... ]}
```

- Only alerts with something to do (`discount`, `donate`, `remove`) are listed and counted in the tiles.
  `monitoring` says how many at-risk batches are being watched with nothing to do yet; add
  `?include_monitor=true` to list them too.
- `expired_or_today` is the "Expired / Today" tile and `due_soon` the next tile. The engine looks
  **2 days** ahead, so label that tile "Next 2 days".
- `total_rm_at_risk` is the "Value at risk" tile.
- `alerts` is already sorted most urgent first. Each alert has `batch_id`, `product_id`, `name`,
  `quantity`, `unit`, `days_left`, `priority`, `issue_type`, `action`, `discount_pct`, `risk`,
  `expected_waste_units`, `rm_at_risk`, `expected_rm_saved` and `explanation` (a sentence to show as is).

### `POST /batches`
Body: `{"product_id": 41, "quantity": 12}`, plus optional `received_date` (defaults to today) and
`expiry_date` (defaults to received date + the product's `shelf_life_days`). Returns the new batch.
Pick `product_id` from `GET /products`, which has each product's `name`, `unit` and `shelf_life_days`.
Supplier, cost, notes and storage location are not stored yet.

### `PATCH /batches/{id}`
Body with either or both: `{"quantity": 8}` (what is left) and `{"status": "discarded"}`.

### `POST /sales/import`
Multipart upload with the file in a field named `file`. Query parameters:
- `dry_run=true` checks every row and saves nothing (the Preview step).
- `date_column`, `product_column`, `quantity_column` name the file's columns (the Map step).
  Defaults: `date`, `product`, `quantity`.

Dates can be `DD/MM/YYYY` or `YYYY-MM-DD`. Products can be names (any case) or product IDs.
Returns every row with its `status`, plus the counts `ok`, `unmatched`, `errors` and `imported`
(0 on a dry run). A file without the named columns gets a `400` whose `detail` lists the file's columns.

## Fixed values

| Field | Values |
|---|---|
| Alert `action` | `discount` (apply `discount_pct`), `donate` (last day, a discount won't sell it), `remove` (expired); `monitor` (at risk, nothing worth doing yet) only with `include_monitor=true` |
| Alert `issue_type` | `expired`, `expiring_soon` |
| Alert `priority` | `high` (expired, or expires today or tomorrow), `medium` (later) |
| Alert `discount_pct` | `0`, `10`, `20` or `30` |
| Alert `risk` | A number from 0 to 1: the chance some of the batch goes unsold. Show as a percentage |
| Batch `status` | `active`, `sold_out`, `discarded` |
| Sales row `status` | `ok`, `unmatched` (product not in the catalog), `bad_date`, `bad_quantity` |
| Product `unit` | `kg`, `packs`, `loaves`, `trays`, `bunches` |
