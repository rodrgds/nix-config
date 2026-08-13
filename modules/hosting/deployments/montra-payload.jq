def exact_keys($allowed):
  ([keys[] | IN($allowed[])] | all) and length == ($allowed | length);

type == "object"
and exact_keys(["repository", "sha", "issued_at", "delivery_id", "components"])
and .repository == "rodrgds/montra"
and (.sha | type == "string" and test("^[0-9a-f]{40}$"))
and (.issued_at | type == "number" and . == floor and . >= 0 and . <= 9999999999)
and (.delivery_id | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9-]{0,127}$"))
and (.components | type == "object" and length > 0)
and (.components | [keys[] | IN("api", "web", "embedding", "detector", "postgres")] | all)
and (.components | [to_entries[] | .value | type == "string" and test("^sha256:[0-9a-f]{64}$")] | all)
