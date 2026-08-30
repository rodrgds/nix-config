if type == "object"
  and (keys | sort == ["api_digest", "delivery_id", "issued_at", "migrate_digest", "repository", "sha", "web_digest", "worker_digest"])
  and .repository == "rodrgds/unprompted"
  and (.sha | type == "string" and test("^[0-9a-f]{40}$"))
  and (.issued_at | type == "number" and . == floor and . >= 0 and . <= 9999999999)
  and (.delivery_id | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9-]{0,127}$"))
  and ([.api_digest, .worker_digest, .web_digest, .migrate_digest] | all(type == "string" and test("^sha256:[0-9a-f]{64}$")))
then .
else error("invalid Unprompted deployment payload")
end
