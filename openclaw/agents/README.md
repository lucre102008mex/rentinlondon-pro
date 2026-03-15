# Supabase RW Tool Usage

Each agent has a **`supabase_rw.json`** tool located in its `TOOLS/` directory. This tool allows the agent to **GET**, **POST**, and **PATCH** data in Supabase.

## Environment variables
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

These are defined in the project root `.env` and are automatically available to all agents.

## How to call the tool
```json
{
  "tool": "supabase_rw",
  "arguments": {
    "method": "GET",
    "table": "bookings",
    "params": "select=*&limit=5",
    "body": ""
  }
}
```
- `method`: `GET`, `POST`, or `PATCH` (DELETE is prohibited).
- `table`: the Supabase table or view you want to query.
- `params`: URL‑encoded query string (e.g., `select=*,agent:agents(id,name)`).
- `body`: JSON payload for `POST`/`PATCH` (empty string for `GET`).

## Example: Get the first 5 bookings
```json
{
  "tool": "supabase_rw",
  "arguments": {
    "method": "GET",
    "table": "bookings",
    "params": "select=*&limit=5",
    "body": ""
  }
}
```
The tool will return a JSON array with the requested rows.

## Example: Create a new lead (POST)
```json
{
  "tool": "supabase_rw",
  "arguments": {
    "method": "POST",
    "table": "leads",
    "params": "",
    "body": "{\"name\": \"Alice\", \"email\": \"alice@example.com\", \"phone\": \"+44 1234 567890\"}"
  }
}
```

## Example: Update a lead's status (PATCH)
```json
{
  "tool": "supabase_rw",
  "arguments": {
    "method": "PATCH",
    "table": "leads?id=eq.<lead-id>",
    "params": "",
    "body": "{\"status\": \"contacted\"}"
  }
}
```

All agents (`alex`, `ivy`, `rose`, `salo`, `jeanette`, `script`, `facebook`, `gumtree`) can use this tool in the same way.
