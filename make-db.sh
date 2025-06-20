#!/usr/bin/env bash

git-history file usd-exchange-rates.db open.er-api.com-v6-latest-USD.json \
  --namespace exchange_rate \
  --id currency_code \
  --convert '
data = json.loads(content)
rates = data["rates"]
base_time = data.get("time_last_update_utc", "")
for currency_code, rate in rates.items():
    yield {
        "currency_code": currency_code,
        "rate": rate,
        "base_code": data["base_code"],
        "time_last_update_utc": base_time,
        "time_last_update_unix": data.get("time_last_update_unix", 0)
    }
'