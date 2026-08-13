def digest:
  type == "string" and test("^sha256:[0-9a-f]{64}$");

type == "object"
and length > 0
and ([keys[] | IN("api", "web", "embedding", "detector", "postgres")] | all)
and ([to_entries[] | .value | digest] | all)
